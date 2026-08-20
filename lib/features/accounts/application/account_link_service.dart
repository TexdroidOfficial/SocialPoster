import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/environment.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/account_models.dart';

class LinkCredentials {
  const LinkCredentials({this.pds, this.identifier, this.appPassword});

  final String? pds;
  final String? identifier;
  final String? appPassword;
}

class LinkedAccountData {
  const LinkedAccountData({
    required this.provider,
    required this.providerAccountId,
    required this.backendAccountId,
    required this.ownerId,
    required this.label,
    required this.capabilities,
    this.serviceEndpoint,
  });

  final SocialProvider provider;
  final String providerAccountId;
  final String backendAccountId;
  final String ownerId;
  final String label;
  final ProviderCapabilities capabilities;
  final String? serviceEndpoint;
}

/// Coordinates social provider linking through the stateless OAuth bridge.
class AccountLinkService {
  AccountLinkService({
    required this.environment,
    Dio? dio,
    FlutterSecureStorage? secureStorage,
  }) : _dio = dio ?? Dio(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final AppEnvironment environment;
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  Future<LinkedAccountData> link(
    SocialProvider provider, {
    LinkCredentials credentials = const LinkCredentials(),
  }) async {
    if (provider != SocialProvider.bluesky &&
        environment.oauthApiBaseUrl.isEmpty) {
      throw const AppFailure(
        FailureKind.authRequired,
        'Configure OAUTH_API_BASE_URL before linking accounts.',
      );
    }
    return provider == SocialProvider.bluesky
        ? _linkBluesky(credentials)
        : _linkOAuth(provider);
  }

  Future<void> disconnect(ConnectedAccount account) async {
    await _secureStorage.delete(key: '${account.provider.name}_access_token');
    await _secureStorage.delete(key: '${account.provider.name}_refresh_token');
  }

  Future<LinkedAccountData> _linkOAuth(SocialProvider provider) async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      environment.oauthCallbackPort,
    );
    final redirectUri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
      path: '/callback',
    );
    try {
      final startResponse = await _dio.get<Map<String, dynamic>>(
        '${environment.oauthApiBaseUrl.replaceFirst(RegExp(r'\/$'), '')}/api/start/${provider.name}',
        queryParameters: {'redirect_uri': redirectUri.toString()},
      );
      final start = startResponse.data ?? const <String, dynamic>{};
      final authorizationUrl = _string(
        start['authorization_url'],
        'OAuth bridge did not return an authorization URL.',
      );
      if (!await launchUrl(
        Uri.parse(authorizationUrl),
        mode: LaunchMode.externalApplication,
      )) {
        throw const AppFailure(
          FailureKind.authRequired,
          'Could not open the system browser for authorization.',
        );
      }
      final callback = await _awaitCallback(server);
      if (callback['error'] != null) {
        throw const AppFailure(
          FailureKind.authRequired,
          'Provider authorization was denied.',
        );
      }
      final accessToken = _string(
        callback['access_token'],
        'OAuth bridge returned no access token.',
      );
      await _secureStorage.write(
        key: '${provider.name}_access_token',
        value: accessToken,
      );
      final refreshToken = callback['refresh_token'];
      if (refreshToken is String && refreshToken.isNotEmpty) {
        await _secureStorage.write(
          key: '${provider.name}_refresh_token',
          value: refreshToken,
        );
      }
      return LinkedAccountData(
        provider: provider,
        providerAccountId: callback['provider_account_id'] ?? 'unknown',
        backendAccountId: callback['provider_account_id'] ?? 'unknown',
        ownerId: 'local-desktop',
        label: callback['label'] ?? provider.label,
        capabilities: _capabilities(callback['capabilities']),
      );
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      throw const AppFailure(
        FailureKind.authRequired,
        'Authorization timed out.',
      );
    } catch (error) {
      throw AppFailure(
        FailureKind.transientNetwork,
        'OAuth authorization failed: $error',
        retryable: true,
      );
    } finally {
      await server.close(force: true);
    }
  }

  Future<LinkedAccountData> _linkBluesky(LinkCredentials credentials) async {
    final pds = _required(credentials.pds, 'Bluesky service URL');
    final identifier = _required(
      credentials.identifier,
      'Bluesky handle or email',
    );
    final appPassword = _required(
      credentials.appPassword,
      'Bluesky app password',
    );
    final session = await _dio.post<Map<String, dynamic>>(
      '$pds/xrpc/com.atproto.server.createSession',
      data: {'identifier': identifier, 'password': appPassword},
    );
    final data = session.data ?? const <String, dynamic>{};
    final accessToken = _string(
      data['accessJwt'],
      'Bluesky returned no token.',
    );
    await _secureStorage.write(key: 'bluesky_access_token', value: accessToken);
    if (data['refreshJwt'] is String) {
      await _secureStorage.write(
        key: 'bluesky_refresh_token',
        value: data['refreshJwt'] as String,
      );
    }
    return LinkedAccountData(
      provider: SocialProvider.bluesky,
      providerAccountId: _string(
        data['did'],
        'Bluesky returned no account ID.',
      ),
      backendAccountId: _string(data['did'], 'Bluesky returned no account ID.'),
      ownerId: 'local-desktop',
      label: data['handle'] as String? ?? 'Bluesky account',
      capabilities: const ProviderCapabilities(
        images: true,
        videos: true,
        carousel: true,
      ),
      serviceEndpoint: pds,
    );
  }

  Future<Map<String, String>> _awaitCallback(HttpServer server) async {
    final completer = Completer<Map<String, String>>();
    final subscription = server.listen((request) {
      if (request.uri.path != '/callback') {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
        return;
      }
      final result = <String, String>{
        for (final entry in request.uri.queryParameters.entries)
          entry.key: entry.value,
      };
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(
          '<!doctype html><title>Authorization complete</title>'
          '<p>You can close this window and return to Signal Post.</p>',
        );
      request.response.close();
      if (!completer.isCompleted) completer.complete(result);
    });
    try {
      return await completer.future.timeout(const Duration(minutes: 3));
    } finally {
      await subscription.cancel();
    }
  }

  ProviderCapabilities _capabilities(Object? value) {
    final values = value is String
        ? Map<String, dynamic>.from(jsonDecode(value) as Map)
        : value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    return ProviderCapabilities(
      images: values['images'] as bool? ?? false,
      videos: values['videos'] as bool? ?? false,
      carousel: values['carousel'] as bool? ?? false,
      thumbnail: values['thumbnail'] as bool? ?? false,
      requiresPublicUrl: values['requiresPublicUrl'] as bool? ?? false,
      videoTransfer: values['videoTransfer'] as bool? ?? false,
      photoTransfer: values['photoTransfer'] as bool? ?? false,
    );
  }

  String _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      throw AppFailure(
        FailureKind.authRequired,
        'Enter your $label to continue.',
      );
    }
    return value.trim();
  }

  String _string(Object? value, String message) {
    if (value is! String || value.isEmpty) {
      throw AppFailure(FailureKind.unknownProviderError, message);
    }
    return value;
  }
}
