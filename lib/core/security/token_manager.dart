import 'dart:async';

import '../errors/app_failure.dart';
import 'oauth.dart';
import 'secret_store.dart';

typedef TokenRefresher = Future<OAuthTokens> Function(OAuthTokens current);

class TokenManager {
  TokenManager(this._secrets);

  final SecretStore _secrets;
  final Map<String, Future<OAuthTokens>> _refreshes = {};

  Future<OAuthTokens?> read(String secretRef) async {
    final encoded = await _secrets.read(secretRef);
    if (encoded == null) return null;
    return _decode(encoded);
  }

  Future<void> write(String secretRef, OAuthTokens tokens) =>
      _secrets.write(secretRef, _encode(tokens));

  Future<OAuthTokens> validToken({
    required String secretRef,
    required TokenRefresher refresh,
  }) async {
    final current = await read(secretRef);
    if (current == null) {
      throw const AppFailure(
        FailureKind.authRequired,
        'This account needs authorization.',
      );
    }
    if (!current.isExpired) return current;
    final pending = _refreshes[secretRef];
    if (pending != null) return pending;
    final operation = _refreshes[secretRef] = _refreshAndStore(
      secretRef,
      current,
      refresh,
    );
    try {
      return await operation;
    } finally {
      _refreshes.remove(secretRef);
    }
  }

  Future<OAuthTokens> _refreshAndStore(
    String secretRef,
    OAuthTokens current,
    TokenRefresher refresh,
  ) async {
    if (current.refreshToken == null) {
      throw const AppFailure(
        FailureKind.tokenRevoked,
        'This account needs authorization again.',
      );
    }
    final refreshed = await refresh(current);
    await write(
      secretRef,
      OAuthTokens(
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken ?? current.refreshToken,
        expiresAt: refreshed.expiresAt,
        scope: refreshed.scope ?? current.scope,
      ),
    );
    return refreshed;
  }

  String _encode(OAuthTokens tokens) => [
    tokens.accessToken,
    tokens.refreshToken ?? '',
    tokens.expiresAt?.toIso8601String() ?? '',
    tokens.scope ?? '',
  ].join('\n');

  OAuthTokens _decode(String value) {
    final parts = value.split('\n');
    if (parts.isEmpty || parts.first.isEmpty) {
      throw const AppFailure(
        FailureKind.tokenRevoked,
        'Stored account credentials are invalid.',
      );
    }
    return OAuthTokens(
      accessToken: parts[0],
      refreshToken: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      expiresAt: parts.length > 2 && parts[2].isNotEmpty
          ? DateTime.tryParse(parts[2])
          : null,
      scope: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
    );
  }
}
