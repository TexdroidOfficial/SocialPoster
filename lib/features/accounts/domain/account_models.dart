enum SocialProvider { youtube, instagram, tiktok, bluesky }

extension ProviderLabel on SocialProvider {
  String get label => switch (this) {
    SocialProvider.youtube => 'YouTube',
    SocialProvider.instagram => 'Instagram',
    SocialProvider.tiktok => 'TikTok',
    SocialProvider.bluesky => 'Bluesky',
  };
}

enum AccountStatus { connected, needsReauth, unavailable }

class ProviderCapabilities {
  const ProviderCapabilities({
    this.images = false,
    this.videos = false,
    this.carousel = false,
    this.thumbnail = false,
    this.requiresPublicUrl = false,
    this.videoTransfer = false,
    this.photoTransfer = false,
  });

  final bool images;
  final bool videos;
  final bool carousel;
  final bool thumbnail;
  final bool requiresPublicUrl;
  final bool videoTransfer;
  final bool photoTransfer;
}

class ConnectedAccount {
  const ConnectedAccount({
    required this.id,
    required this.ownerId,
    required this.provider,
    required this.providerAccountId,
    required this.label,
    required this.backendAccountId,
    required this.capabilities,
    this.serviceEndpoint,
    this.status = AccountStatus.connected,
    this.lastValidatedAt,
  });

  final String id;
  final String ownerId;
  final SocialProvider provider;
  final String providerAccountId;
  final String label;
  final String backendAccountId;
  final ProviderCapabilities capabilities;
  final String? serviceEndpoint;
  final AccountStatus status;
  final DateTime? lastValidatedAt;
}
