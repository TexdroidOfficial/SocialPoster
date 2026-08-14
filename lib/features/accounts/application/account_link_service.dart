import 'dart:convert';
import 'dart:io';

import '../../../core/config/environment.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/security/oauth.dart';
import '../domain/account_models.dart';

class LinkCredentials {
  const LinkCredentials({
    this.clientId,
    this.clientSecret,
    this.redirectUri,
    this.pds,
    this.identifier,
    this.appPassword,
  });

  final String? clientId;
  final String? clientSecret;
  final String? redirectUri;
  final String? pds;
  final String? identifier;
  final String? appPassword;
}

class LinkedAccountData {
  const LinkedAccountData({
    required this.provider,
    required this.providerAccountId,
    required this.label,
    required this.tokens,
    required this.capabilities,
    this.serviceEndpoint,
  });

  final SocialProvider provider;
  final String providerAccountId;
  final String label;
  final OAuthTokens tokens;
  final ProviderCapabilities capabilities;
  final String? serviceEndpoint;
}

class AccountLinkService {
  AccountLinkService({required this.environment, OAuthFlow? oauth})
    : _oauth = oauth ?? OAuthFlow();

  final AppEnvironment environment;
  final OAuthFlow _oauth;

  Future<LinkedAccountData> link(
    SocialProvider provider, {
    LinkCredentials credentials = const LinkCredentials(),
  }) async {
    return switch (provider) {
      SocialProvider.youtube => _linkYouTube(credentials),
      SocialProvider.instagram => _linkInstagram(credentials),
      SocialProvider.tiktok => _linkTikTok(credentials),
      SocialProvider.bluesky => _linkBluesky(credentials),
    };
  }

  Future<LinkedAccountData> linkBluesky({
    required String pds,
    required String identifier,
    required String appPassword,
  }) => _linkBluesky(
    LinkCredentials(pds: pds, identifier: identifier, appPassword: appPassword),
  );

  Future<LinkedAccountData> _linkYouTube(LinkCredentials credentials) async {
    final clientId = environment.youtubeClientId;
    if (clientId.isEmpty) {
      throw const AppFailure(
        FailureKind.authRequired,
        'Set YOUTUBE_CLIENT_ID before linking a YouTube channel.',
      );
    }
    final tokens = await _oauth.authorize(
      config: OAuthProviderConfig(
        authorizationEndpoint: Uri.parse(
          'https://accounts.google.com/o/oauth2/v2/auth',
        ),
        tokenEndpoint: Uri.parse('https://oauth2.googleapis.com/token'),
        clientId: clientId,
        scopes: const [
          'https://www.googleapis.com/auth/youtube.upload',
          'https://www.googleapis.com/auth/youtube.readonly',
        ],
        fixedRedirectUri: _optionalUri(environment.youtubeRedirectUri),
      ),
    );
    final profile = await _getJson(
      Uri.parse(
        'https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true',
      ),
      tokens.accessToken,
    );
    final item = _firstItem(
      profile,
      'YouTube did not return a channel for this account.',
    );
    final snippet = _map(item['snippet']);
    return LinkedAccountData(
      provider: SocialProvider.youtube,
      providerAccountId: _string(
        item['id'],
        'YouTube response did not include a channel ID.',
      ),
      label: _string(snippet['title'], 'YouTube channel'),
      tokens: tokens,
      capabilities: const ProviderCapabilities(videos: true, thumbnail: true),
    );
  }

  Future<LinkedAccountData> _linkInstagram(LinkCredentials credentials) async {
    final clientId = _required(credentials.clientId, 'Instagram client ID');
    final clientSecret = _required(
      credentials.clientSecret,
      'Instagram client secret',
    );
    final redirect = _required(
      credentials.redirectUri,
      'Instagram redirect URI',
    );
    final tokens = await _oauth.authorize(
      config: OAuthProviderConfig(
        authorizationEndpoint: Uri.parse(
          'https://www.instagram.com/oauth/authorize',
        ),
        tokenEndpoint: Uri.parse(
          'https://api.instagram.com/oauth/access_token',
        ),
        clientId: clientId,
        clientSecret: clientSecret,
        fixedRedirectUri: Uri.parse(redirect),
        scopes: const [
          'instagram_business_basic',
          'instagram_business_content_publish',
        ],
        usePkce: false,
      ),
    );
    final profile = await _getJson(
      Uri.parse('https://graph.instagram.com/v22.0/me?fields=id,username'),
      tokens.accessToken,
    );
    return LinkedAccountData(
      provider: SocialProvider.instagram,
      providerAccountId: _string(
        profile['id'],
        'Instagram response did not include an account ID.',
      ),
      label: _string(profile['username'], 'Instagram professional account'),
      tokens: tokens,
      capabilities: const ProviderCapabilities(
        images: true,
        videos: true,
        carousel: true,
        requiresPublicUrl: true,
      ),
    );
  }

  Future<LinkedAccountData> _linkTikTok(LinkCredentials credentials) async {
    final clientId = _required(
      credentials.clientId ?? environment.tiktokClientId,
      'TikTok client key',
    );
    final clientSecret = _required(
      credentials.clientSecret ?? environment.tiktokClientSecret,
      'TikTok client secret',
    );
    final redirect = _required(
      credentials.redirectUri ?? environment.tiktokRedirectUri,
      'TikTok redirect URI',
    );
    final tokens = await _oauth.authorize(
      config: OAuthProviderConfig(
        authorizationEndpoint: Uri.parse(
          'https://www.tiktok.com/v2/auth/authorize/',
        ),
        tokenEndpoint: Uri.parse(
          '${environment.tiktokApiBaseUrl}/v2/oauth/token/',
        ),
        clientId: clientId,
        clientSecret: clientSecret,
        fixedRedirectUri: Uri.parse(redirect),
        authorizationParameters: {'client_key': clientId},
        tokenParameters: {'client_key': clientId},
        scopes: const ['user.info.basic', 'video.publish', 'video.upload'],
        usePkce: true,
      ),
    );
    final profile = await _getJson(
      Uri.parse(
        '${environment.tiktokApiBaseUrl}/v2/user/info/?fields=open_id,display_name',
      ),
      tokens.accessToken,
    );
    final data = _map(profile['data']);
    final user = _map(data['user']);
    return LinkedAccountData(
      provider: SocialProvider.tiktok,
      providerAccountId: _string(
        user['open_id'],
        'TikTok response did not include an account ID.',
      ),
      label: _string(user['display_name'], 'TikTok account'),
      tokens: tokens,
      capabilities: const ProviderCapabilities(
        images: true,
        videos: true,
        videoTransfer: true,
        photoTransfer: true,
      ),
    );
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
    final response = await _postJson(
      Uri.parse('$pds/xrpc/com.atproto.server.createSession'),
      body: {'identifier': identifier, 'password': appPassword},
    );
    final did = _string(
      response['did'],
      'Bluesky response did not include a DID.',
    );
    final handle = _string(response['handle'], identifier);
    return LinkedAccountData(
      provider: SocialProvider.bluesky,
      providerAccountId: did,
      label: handle,
      tokens: OAuthTokens(
        accessToken: _string(
          response['accessJwt'],
          'Bluesky response did not include a session token.',
        ),
        refreshToken: response['refreshJwt'] as String?,
      ),
      capabilities: const ProviderCapabilities(
        images: true,
        videos: true,
        carousel: true,
      ),
      serviceEndpoint: pds,
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, String accessToken) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      return await _readJson(await request.close());
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri, {
    required Map<String, String> body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      return await _readJson(await request.close());
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _readJson(HttpClientResponse response) async {
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AppFailure(
        FailureKind.providerRejected,
        'The provider rejected account linking.',
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const AppFailure(
        FailureKind.unknownProviderError,
        'The provider returned an invalid account response.',
      );
    }
    return decoded;
  }

  Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};

  Map<String, dynamic> _firstItem(
    Map<String, dynamic> response,
    String message,
  ) {
    final items = response['items'];
    if (items is! List ||
        items.isEmpty ||
        items.first is! Map<String, dynamic>) {
      throw AppFailure(FailureKind.unsupportedAccount, message);
    }
    return items.first as Map<String, dynamic>;
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

  Uri? _optionalUri(String value) =>
      value.trim().isEmpty ? null : Uri.parse(value.trim());
}
