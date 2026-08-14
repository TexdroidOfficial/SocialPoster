import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

import '../errors/app_failure.dart';

class OAuthProviderConfig {
  const OAuthProviderConfig({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.clientId,
    required this.scopes,
    this.fixedRedirectUri,
    this.usePkce = true,
  });

  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final String clientId;
  final List<String> scopes;
  final Uri? fixedRedirectUri;
  final bool usePkce;
}

class OAuthTokens {
  const OAuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.scope,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? scope;

  bool get isExpired =>
      expiresAt != null &&
      DateTime.now().isAfter(expiresAt!.subtract(const Duration(minutes: 1)));
}

class OAuthCallbackResult {
  const OAuthCallbackResult({required this.code, required this.state});
  final String code;
  final String state;
}

class OAuthFlow {
  OAuthFlow({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  Future<OAuthTokens> authorize({
    required OAuthProviderConfig config,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final state = _randomString(32);
    final verifier = _randomString(64);
    final server = config.fixedRedirectUri == null
        ? await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
        : null;
    final redirect =
        config.fixedRedirectUri ??
        Uri.parse('http://127.0.0.1:${server!.port}/oauth/callback');
    try {
      final authorizationUri = config.authorizationEndpoint.replace(
        queryParameters: {
          ...config.authorizationEndpoint.queryParameters,
          'client_id': config.clientId,
          'response_type': 'code',
          'redirect_uri': redirect.toString(),
          'scope': config.scopes.join(' '),
          'state': state,
          if (config.usePkce) 'code_challenge': _challenge(verifier),
          if (config.usePkce) 'code_challenge_method': 'S256',
        },
      );
      if (!await launchUrl(
        authorizationUri,
        mode: LaunchMode.externalApplication,
      )) {
        throw const AppFailure(
          FailureKind.authRequired,
          'Could not open the system browser for authorization.',
        );
      }
      final callback = await _awaitCallback(server, state).timeout(timeout);
      final response = await _exchangeCode(
        config,
        callback.code,
        redirect,
        verifier,
      );
      return _parseTokens(response);
    } on TimeoutException {
      throw const AppFailure(
        FailureKind.authRequired,
        'Authorization timed out.',
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        FailureKind.authRequired,
        'Authorization could not be completed.',
      );
    } finally {
      await server?.close(force: true);
    }
  }

  Future<OAuthCallbackResult> _awaitCallback(
    HttpServer? server,
    String expectedState,
  ) async {
    if (server == null) {
      throw const AppFailure(
        FailureKind.authRequired,
        'This provider requires a registered redirect callback.',
      );
    }
    await for (final request in server) {
      final query = request.uri.queryParameters;
      request.response.statusCode = query.containsKey('code') ? 200 : 400;
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<html><body>You may return to Signal Post.</body></html>',
      );
      await request.response.close();
      if (query['state'] != expectedState) {
        throw const AppFailure(
          FailureKind.authRequired,
          'Authorization state validation failed.',
        );
      }
      if (query['error'] != null) {
        throw AppFailure(
          FailureKind.authRequired,
          'Authorization was denied: ${query['error']}.',
        );
      }
      final code = query['code'];
      if (code == null || code.isEmpty) {
        throw const AppFailure(
          FailureKind.authRequired,
          'Authorization callback did not include a code.',
        );
      }
      return OAuthCallbackResult(code: code, state: expectedState);
    }
    throw const AppFailure(
      FailureKind.authRequired,
      'Authorization callback closed unexpectedly.',
    );
  }

  Future<Map<String, dynamic>> _exchangeCode(
    OAuthProviderConfig config,
    String code,
    Uri redirect,
    String verifier,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(config.tokenEndpoint);
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(
        Uri(
          queryParameters: {
            'grant_type': 'authorization_code',
            'code': code,
            'redirect_uri': redirect.toString(),
            'client_id': config.clientId,
            if (config.usePkce) 'code_verifier': verifier,
          },
        ).query,
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const AppFailure(
          FailureKind.authRequired,
          'The provider rejected authorization.',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const AppFailure(
          FailureKind.authRequired,
          'The provider returned an invalid token response.',
        );
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  OAuthTokens _parseTokens(Map<String, dynamic> json) {
    final access = json['access_token'];
    if (access is! String || access.isEmpty) {
      throw const AppFailure(
        FailureKind.authRequired,
        'The provider returned no access token.',
      );
    }
    final expires = json['expires_in'];
    return OAuthTokens(
      accessToken: access,
      refreshToken: json['refresh_token'] as String?,
      expiresAt: expires is num
          ? DateTime.now().add(Duration(seconds: expires.toInt()))
          : null,
      scope: json['scope'] as String?,
    );
  }

  String _randomString(int length) {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    return List.generate(
      length,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  String _challenge(String verifier) => base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');
}
