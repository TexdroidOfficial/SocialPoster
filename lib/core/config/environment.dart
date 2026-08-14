class AppEnvironment {
  const AppEnvironment({
    this.youtubeClientId = const String.fromEnvironment('YOUTUBE_CLIENT_ID'),
    this.instagramApiVersion = const String.fromEnvironment(
      'INSTAGRAM_API_VERSION',
      defaultValue: 'v22.0',
    ),
    this.tiktokApiBaseUrl = const String.fromEnvironment(
      'TIKTOK_API_BASE_URL',
      defaultValue: 'https://open.tiktokapis.com',
    ),
    this.blueskyPds = const String.fromEnvironment(
      'BLUESKY_PDS',
      defaultValue: 'https://bsky.social',
    ),
  });

  final String youtubeClientId;
  final String instagramApiVersion;
  final String tiktokApiBaseUrl;
  final String blueskyPds;

  factory AppEnvironment.fromPlatform() => const AppEnvironment();
}
