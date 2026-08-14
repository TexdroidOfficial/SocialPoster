import 'bluesky/bluesky_adapter.dart';
import '../features/accounts/domain/account_models.dart';
import 'instagram/instagram_adapter.dart';
import 'provider.dart';
import 'tiktok/tiktok_adapter.dart';
import 'youtube/youtube_adapter.dart';

class ProviderRegistry {
  ProviderRegistry([List<SocialProviderAdapter>? adapters])
    : adapters =
          adapters ??
          [
            YouTubeAdapter(),
            InstagramAdapter(),
            TikTokAdapter(),
            BlueskyAdapter(),
          ];

  final List<SocialProviderAdapter> adapters;

  SocialProviderAdapter forProvider(SocialProvider provider) =>
      adapters.firstWhere((adapter) => adapter.provider == provider);
}
