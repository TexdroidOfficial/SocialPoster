import '../../core/concurrency/cancellation.dart';
import '../../core/errors/app_failure.dart';
import '../../features/accounts/domain/account_models.dart';
import '../../features/media/domain/media_models.dart';
import '../../features/publishing/domain/publish_models.dart';
import '../provider.dart';

class YouTubeAdapter implements SocialProviderAdapter {
  @override
  SocialProvider get provider => SocialProvider.youtube;

  @override
  ProviderCapabilities get capabilities =>
      const ProviderCapabilities(videos: true, thumbnail: true);

  @override
  Future<PreflightResult> preflight({
    required ConnectedAccount account,
    required PublishIntent intent,
  }) async {
    if (intent.assets.length != 1 ||
        intent.assets.single.kind != MediaKind.video) {
      return unsupported(
        'YouTube publishes video uploads. Use an image as an optional thumbnail, not a standalone post.',
      );
    }
    if (intent.videoTitle == null || intent.videoTitle!.trim().isEmpty) {
      return const PreflightResult.blocked(
        AppFailure(
          FailureKind.invalidMetadata,
          'A YouTube video title is required.',
        ),
      );
    }
    if (account.status != AccountStatus.connected) {
      return const PreflightResult.blocked(
        AppFailure(
          FailureKind.authRequired,
          'Connect or re-authorize this YouTube channel.',
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
        'Preparing resumable YouTube upload',
      ),
    );
    throw const AppFailure(
      FailureKind.authRequired,
      'YouTube upload transport is awaiting a connected OAuth channel.',
    );
  }
}
