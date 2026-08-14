import '../../core/concurrency/cancellation.dart';
import '../../core/errors/app_failure.dart';
import '../../features/accounts/domain/account_models.dart';
import '../../features/publishing/domain/publish_models.dart';
import '../provider.dart';

class InstagramAdapter implements SocialProviderAdapter {
  @override
  SocialProvider get provider => SocialProvider.instagram;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    images: true,
    videos: true,
    carousel: true,
    requiresPublicUrl: true,
  );

  @override
  Future<PreflightResult> preflight({
    required ConnectedAccount account,
    required PublishIntent intent,
  }) async {
    if (!intent.assets.every((asset) => asset.hasPublicHttpsUrl)) {
      return const PreflightResult.blocked(
        AppFailure(
          FailureKind.missingPublicUrl,
          'Instagram requires a publicly reachable HTTPS media URL. Local-only files are blocked before submission.',
        ),
      );
    }
    if (intent.assets.length > 1 && !account.capabilities.carousel) {
      return unsupported('This Instagram account cannot publish a carousel.');
    }
    if (account.status != AccountStatus.connected) {
      return const PreflightResult.blocked(
        AppFailure(
          FailureKind.authRequired,
          'Connect or re-authorize this Instagram professional account.',
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
        'Creating Instagram media container',
      ),
    );
    throw const AppFailure(
      FailureKind.providerRejected,
      'Instagram Graph API transport requires a configured Meta app and public asset host.',
    );
  }
}
