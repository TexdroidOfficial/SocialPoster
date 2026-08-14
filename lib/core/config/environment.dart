class AppEnvironment {
  const AppEnvironment({
    this.youtubeClientId = const String.fromEnvironment('YOUTUBE_CLIENT_ID'),
    this.youtubeRedirectUri = const String.fromEnvironment(
      'YOUTUBE_REDIRECT_URI',
    ),
    this.instagramApiVersion = const String.fromEnvironment(
      'INSTAGRAM_API_VERSION',
      defaultValue: 'v22.0',
    ),
    this.tiktokApiBaseUrl = const String.fromEnvironment(
      'TIKTOK_API_BASE_URL',
      defaultValue: 'https://open.tiktokapis.com',
    ),
    this.tiktokClientId = const String.fromEnvironment('TIKTOK_CLIENT_ID'),
    this.tiktokClientSecret = const String.fromEnvironment(
      'TIKTOK_CLIENT_SECRET',
    ),
    this.tiktokRedirectUri = const String.fromEnvironment(
      'TIKTOK_REDIRECT_URI',
    ),
    this.blueskyPds = const String.fromEnvironment(
      'BLUESKY_PDS',
      defaultValue: 'https://bsky.social',
    ),
  });

  final String youtubeClientId;
  final String youtubeRedirectUri;
  final String instagramApiVersion;
  final String tiktokApiBaseUrl;
  final String tiktokClientId;
  final String tiktokClientSecret;
  final String tiktokRedirectUri;
  final String blueskyPds;

  factory AppEnvironment.fromPlatform() => const AppEnvironment();
}
