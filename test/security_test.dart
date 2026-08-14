import 'package:flutter_test/flutter_test.dart';

import 'package:social_poster/core/http/retry_policy.dart';

import 'dart:io';

import 'package:social_poster/core/errors/app_failure.dart';
import 'package:social_poster/core/media/media_intake.dart';
import 'package:social_poster/core/security/oauth.dart';
import 'package:social_poster/core/security/secret_store.dart';
import 'package:social_poster/core/security/token_manager.dart';

void main() {
  test('OAuth token expiry has a refresh safety window', () {
    final expired = OAuthTokens(
      accessToken: 'safe',
      expiresAt: DateTime.now().add(const Duration(seconds: 30)),
    );
    expect(expired.isExpired, isTrue);
  });

  test('retry policy honors provider retry-after values', () {
    const policy = RetryPolicy();
    expect(
      policy.delayFor(1, retryAfterSeconds: 4),
      const Duration(seconds: 4),
    );
  });

  test(
    'token manager coalesces concurrent refreshes and rotates tokens',
    () async {
      final secrets = MemorySecretStore();
      final manager = TokenManager(secrets);
      await manager.write(
        'account',
        OAuthTokens(
          accessToken: 'old',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      var calls = 0;
      final futures = [
        manager.validToken(
          secretRef: 'account',
          refresh: (current) async {
            calls++;
            return OAuthTokens(
              accessToken: 'new',
              refreshToken: 'rotated',
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
            );
          },
        ),
        manager.validToken(
          secretRef: 'account',
          refresh: (current) async {
            calls++;
            return OAuthTokens(
              accessToken: 'new',
              refreshToken: 'rotated',
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
            );
          },
        ),
      ];
      final tokens = await Future.wait(futures);
      expect(calls, 1);
      expect(tokens.first.accessToken, 'new');
      expect((await manager.read('account'))?.refreshToken, 'rotated');
    },
  );

  test('media snapshots detect a changed source before transfer', () async {
    final directory = await Directory.systemTemp.createTemp(
      'social-poster-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/asset.png');
    await file.writeAsString('first');
    final intake = MediaIntake();
    final asset = await intake.snapshot(file.path);
    await file.writeAsString('second content');
    expect(intake.verifyUnchanged(asset), throwsA(isA<AppFailure>()));
  });
}
