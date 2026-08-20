import 'package:flutter_riverpod/flutter_riverpod.dart';

final appEnvironmentProvider = Provider<AppEnvironment>(
  (_) => const AppEnvironment(),
);

class AppEnvironment {
  const AppEnvironment({
    this.oauthApiBaseUrl = const String.fromEnvironment('OAUTH_API_BASE_URL'),
    this.oauthCallbackPort = const int.fromEnvironment(
      'OAUTH_CALLBACK_PORT',
      defaultValue: 8080,
    ),
    this.blueskyPds = const String.fromEnvironment(
      'BLUESKY_PDS',
      defaultValue: 'https://bsky.social',
    ),
  });

  final String oauthApiBaseUrl;
  final int oauthCallbackPort;
  final String blueskyPds;

  factory AppEnvironment.fromPlatform() => const AppEnvironment();
}
