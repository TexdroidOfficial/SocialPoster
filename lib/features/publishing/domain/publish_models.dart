import '../../accounts/domain/account_models.dart';
import '../../media/domain/media_models.dart';
import '../../../core/errors/app_failure.dart';

enum Privacy { public, unlisted, private }

enum DestinationState {
  queued,
  validating,
  blocked,
  ready,
  uploading,
  processing,
  succeeded,
  failed,
  cancelled,
  needsReauth,
}

enum UploadPhase {
  preparing,
  transferring,
  remoteProcessing,
  publishing,
  completed,
}

class PublishIntent {
  const PublishIntent({
    required this.operationId,
    required this.assets,
    required this.caption,
    required this.accounts,
    this.privacy = Privacy.private,
    this.videoTitle,
    this.altText,
    this.thumbnail,
  });

  final String operationId;
  final List<MediaAsset> assets;
  final String caption;
  final List<ConnectedAccount> accounts;
  final Privacy privacy;
  final String? videoTitle;
  final String? altText;
  final MediaAsset? thumbnail;
}

class PreflightResult {
  const PreflightResult.ready() : failure = null;
  const PreflightResult.blocked(this.failure);

  final AppFailure? failure;
  bool get isReady => failure == null;
}

class DestinationTask {
  const DestinationTask({
    required this.id,
    required this.jobId,
    required this.provider,
    required this.account,
    this.state = DestinationState.queued,
    this.phase = UploadPhase.preparing,
    this.progress = 0,
    this.attempts = 0,
    this.providerOperationId,
    this.failure,
  });

  final String id;
  final String jobId;
  final SocialProvider provider;
  final ConnectedAccount account;
  final DestinationState state;
  final UploadPhase phase;
  final double progress;
  final int attempts;
  final String? providerOperationId;
  final AppFailure? failure;

  DestinationTask copyWith({
    DestinationState? state,
    UploadPhase? phase,
    double? progress,
    int? attempts,
    String? providerOperationId,
    AppFailure? failure,
  }) => DestinationTask(
    id: id,
    jobId: jobId,
    provider: provider,
    account: account,
    state: state ?? this.state,
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    attempts: attempts ?? this.attempts,
    providerOperationId: providerOperationId ?? this.providerOperationId,
    failure: failure ?? this.failure,
  );
}

class UploadJob {
  const UploadJob({
    required this.id,
    required this.intent,
    required this.tasks,
    this.createdAt,
  });

  final String id;
  final PublishIntent intent;
  final List<DestinationTask> tasks;
  final DateTime? createdAt;

  bool get isComplete =>
      tasks.isNotEmpty &&
      tasks.every(
        (task) => switch (task.state) {
          DestinationState.queued ||
          DestinationState.validating ||
          DestinationState.ready ||
          DestinationState.uploading ||
          DestinationState.processing => false,
          _ => true,
        },
      );

  bool get partiallySucceeded =>
      tasks.any((task) => task.state == DestinationState.succeeded) &&
      tasks.any((task) => task.state != DestinationState.succeeded);
}
