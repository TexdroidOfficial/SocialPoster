import '../../core/concurrency/cancellation.dart';
import '../../core/errors/app_failure.dart';
import '../../features/accounts/domain/account_models.dart';
import '../../features/media/domain/media_models.dart';
import '../../features/publishing/domain/publish_models.dart';
import '../provider.dart';

class BlueskyAdapter implements SocialProviderAdapter {
  @override
  SocialProvider get provider => SocialProvider.bluesky;

  @override
  ProviderCapabilities get capabilities =>
      const ProviderCapabilities(images: true, videos: true, carousel: true);

  @override
  Future<PreflightResult> preflight({
    required ConnectedAccount account,
    required PublishIntent intent,
  }) async {
    if (intent.assets.length > 4 ||
        intent.assets.any((asset) => asset.kind == MediaKind.video) &&
            intent.assets.length != 1) {
      return unsupported(
        'Bluesky supports up to four images or one video in a post.',
      );
    }
    if (account.status != AccountStatus.connected) {
      return const PreflightResult.blocked(
        AppFailure(
          FailureKind.authRequired,
          'Connect or re-authorize this Bluesky account.',
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
        UploadPhase.transferring,
        0,
        'Uploading blobs to the configured PDS',
      ),
    );
    throw const AppFailure(
      FailureKind.authRequired,
      'Bluesky publishing requires an app password session.',
    );
  }
}
