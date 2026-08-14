import '../../core/concurrency/cancellation.dart';
import '../../core/errors/app_failure.dart';
import '../../features/accounts/domain/account_models.dart';
import '../../features/media/domain/media_models.dart';
import '../../features/publishing/domain/publish_models.dart';
import '../provider.dart';

class TikTokAdapter implements SocialProviderAdapter {
  @override
  SocialProvider get provider => SocialProvider.tiktok;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    videos: true,
    images: true,
    videoTransfer: true,
    photoTransfer: true,
  );

  @override
  Future<PreflightResult> preflight({
    required ConnectedAccount account,
    required PublishIntent intent,
  }) async {
    if (intent.assets.isEmpty ||
        intent.assets.length >
            (intent.assets.first.kind == MediaKind.image ? 35 : 1)) {
      return unsupported(
        'TikTok photo and video posts have separate media-count contracts.',
      );
    }
    if (account.status != AccountStatus.connected) {
      return const PreflightResult.blocked(
        AppFailure(
          FailureKind.authRequired,
          'Connect or re-authorize this TikTok account.',
        ),
      );
    }
    return const PreflightResult.ready();
  }

  @override
  Future<ProviderPublishResult> publish({
    required ConnectedAccount account,
    required PublishIntent intent,
    required CancellationToken cancellation,
    required void Function(ProviderProgress progress) onProgress,
  }) async {
    cancellation.throwIfCancelled();
    onProgress(
      const ProviderProgress(
        UploadPhase.preparing,
        0,
        'Checking TikTok creator capabilities',
      ),
    );
    throw const AppFailure(
      FailureKind.providerRejected,
      'TikTok Content Posting API requires an approved app and eligible creator account.',
    );
  }
}
