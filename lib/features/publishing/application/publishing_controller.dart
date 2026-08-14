import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/concurrency/cancellation.dart';
import '../../../core/errors/app_failure.dart';
import '../../../providers/registry.dart';
import '../../accounts/application/account_controller.dart';
import '../../accounts/domain/account_models.dart';
import '../../media/domain/media_models.dart';
import '../domain/publish_models.dart';

final providerRegistry = Provider<ProviderRegistry>((_) => ProviderRegistry());
final publishingControllerProvider =
    NotifierProvider<PublishingController, PublishingState>(
      PublishingController.new,
    );

class PublishingState {
  const PublishingState({this.job, this.isPublishing = false});
  final UploadJob? job;
  final bool isPublishing;
}

class PublishingController extends Notifier<PublishingState> {
  final Map<String, CancellationToken> _cancellations = {};

  @override
  PublishingState build() => const PublishingState();

  Future<UploadJob> publish({
    required List<MediaAsset> assets,
    required String caption,
    required List<ConnectedAccount> accounts,
    Privacy privacy = Privacy.private,
    String? videoTitle,
  }) async {
    final operationId = const Uuid().v4();
    final intent = PublishIntent(
      operationId: operationId,
      assets: assets,
      caption: caption,
      accounts: accounts,
      privacy: privacy,
      videoTitle: videoTitle,
    );
    final tasks = accounts
        .map(
          (account) => DestinationTask(
            id: const Uuid().v4(),
            jobId: operationId,
            provider: account.provider,
            account: account,
          ),
        )
        .toList();
    var job = UploadJob(
      id: operationId,
      intent: intent,
      tasks: tasks,
      createdAt: DateTime.now(),
    );
    state = PublishingState(job: job, isPublishing: true);
    _persistJob(job);
    final semaphore = AsyncSemaphore(3);
    await Future.wait(
      tasks.map(
        (task) => semaphore.withPermit(() async {
          final result = await _runTask(job, task);
          job = UploadJob(
            id: job.id,
            intent: job.intent,
            tasks: [
              for (final current in job.tasks)
                current.id == result.id ? result : current,
            ],
            createdAt: job.createdAt,
          );
          state = PublishingState(job: job, isPublishing: !job.isComplete);
          _persistTask(result);
        }),
      ),
    );
    state = PublishingState(job: job, isPublishing: false);
    return job;
  }

  void cancel() {
    for (final cancellation in _cancellations.values) {
      cancellation.cancel();
    }
  }

  Future<DestinationTask> _runTask(UploadJob job, DestinationTask task) async {
    final adapter = ref.read(providerRegistry).forProvider(task.provider);
    var current = task.copyWith(state: DestinationState.validating);
    _persistTask(current);
    final preflight = await adapter.preflight(
      account: task.account,
      intent: job.intent,
    );
    if (!preflight.isReady) {
      return current.copyWith(
        state: DestinationState.blocked,
        failure: preflight.failure,
      );
    }
    current = current.copyWith(state: DestinationState.uploading);
    final cancellation = CancellationToken();
    _cancellations[task.id] = cancellation;
    try {
      final result = await adapter.publish(
        account: task.account,
        intent: job.intent,
        cancellation: cancellation,
        onProgress: (progress) {
          current = current.copyWith(
            phase: progress.phase,
            progress: progress.value,
          );
          state = PublishingState(job: job, isPublishing: true);
        },
      );
      return current.copyWith(
        state: DestinationState.succeeded,
        phase: UploadPhase.completed,
        progress: 1,
        providerOperationId: result.operationId,
      );
    } on AppFailure catch (failure) {
      return current.copyWith(
        state:
            failure.kind == FailureKind.authRequired ||
                failure.kind == FailureKind.tokenRevoked
            ? DestinationState.needsReauth
            : DestinationState.failed,
        failure: failure,
      );
    } on StateError {
      return current.copyWith(
        state: DestinationState.cancelled,
        failure: const AppFailure(
          FailureKind.cancelled,
          'Publishing was cancelled.',
        ),
      );
    } finally {
      _cancellations.remove(task.id);
    }
  }

  void _persistJob(UploadJob job) {
    ref
        .read(databaseProvider)
        .insertJob(
          values: {
            'id': job.id,
            'caption': job.intent.caption,
            'created_at': job.createdAt?.toIso8601String(),
            'state': 'running',
            'intent_json': jsonEncode({
              'operationId': job.intent.operationId,
              'assetIds': job.intent.assets.map((asset) => asset.id).toList(),
              'videoTitle': job.intent.videoTitle,
            }),
          },
        );
    for (final task in job.tasks) {
      _persistTask(task);
    }
  }

  void _persistTask(DestinationTask task) {
    ref
        .read(databaseProvider)
        .insertDestination(
          values: {
            'id': task.id,
            'job_id': task.jobId,
            'provider': task.provider.name,
            'account_id': task.account.id,
            'state': task.state.name,
            'phase': task.phase.name,
            'progress': task.progress,
            'attempts': task.attempts,
            'provider_operation_id': task.providerOperationId,
            'error_kind': task.failure?.kind.name,
            'error_message': task.failure?.message,
          },
        );
  }
}
