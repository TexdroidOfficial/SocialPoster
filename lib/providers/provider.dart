import '../core/concurrency/cancellation.dart';
import '../core/errors/app_failure.dart';
import '../features/accounts/domain/account_models.dart';
import '../features/publishing/domain/publish_models.dart';

class ProviderProgress {
  const ProviderProgress(this.phase, this.value, this.message);

  final UploadPhase phase;
  final double value;
  final String message;
}

class ProviderPublishResult {
  const ProviderPublishResult({this.operationId, this.resultUrl});

  final String? operationId;
  final String? resultUrl;
}

abstract interface class SocialProviderAdapter {
  SocialProvider get provider;
  ProviderCapabilities get capabilities;

  Future<PreflightResult> preflight({
    required ConnectedAccount account,
    required PublishIntent intent,
  });

  Future<ProviderPublishResult> publish({
    required ConnectedAccount account,
    required PublishIntent intent,
    required CancellationToken cancellation,
    required void Function(ProviderProgress progress) onProgress,
  });
}

PreflightResult unsupported(String message) =>
    PreflightResult.blocked(AppFailure(FailureKind.unsupportedMedia, message));
