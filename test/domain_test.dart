import 'package:flutter_test/flutter_test.dart';

import 'package:social_poster/core/errors/app_failure.dart';
import 'package:social_poster/features/accounts/domain/account_models.dart';
import 'package:social_poster/features/media/domain/media_models.dart';
import 'package:social_poster/features/publishing/domain/publish_models.dart';
import 'package:social_poster/providers/instagram/instagram_adapter.dart';
import 'package:social_poster/providers/youtube/youtube_adapter.dart';

void main() {
  test('YouTube blocks image-only intents', () async {
    final account = ConnectedAccount(
      id: 'account',
      provider: SocialProvider.youtube,
      providerAccountId: 'channel',
      label: 'Channel',
      secretRef: 'secret',
      capabilities: const ProviderCapabilities(videos: true),
    );
    final asset = MediaAsset(
      id: 'image',
      path: '/tmp/post.png',
      kind: MediaKind.image,
      mime: 'image/png',
      bytes: 10,
      modifiedAt: DateTime(2026),
    );
    final result = await YouTubeAdapter().preflight(
      account: account,
      intent: PublishIntent(
        operationId: 'job',
        assets: [asset],
        caption: '',
        accounts: [account],
      ),
    );
    expect(result.failure?.kind, FailureKind.unsupportedMedia);
  });

  test('YouTube requires a video title', () async {
    final account = ConnectedAccount(
      id: 'account',
      provider: SocialProvider.youtube,
      providerAccountId: 'channel',
      label: 'Channel',
      secretRef: 'secret',
      capabilities: const ProviderCapabilities(videos: true),
    );
    final asset = MediaAsset(
      id: 'video',
      path: '/tmp/post.mp4',
      kind: MediaKind.video,
      mime: 'video/mp4',
      bytes: 10,
      modifiedAt: DateTime(2026),
    );
    final result = await YouTubeAdapter().preflight(
      account: account,
      intent: PublishIntent(
        operationId: 'job',
        assets: [asset],
        caption: '',
        accounts: [account],
      ),
    );
    expect(result.failure?.kind, FailureKind.invalidMetadata);
  });

  test('Instagram blocks local-only media before network submission', () async {
    final account = ConnectedAccount(
      id: 'account',
      provider: SocialProvider.instagram,
      providerAccountId: 'profile',
      label: 'Profile',
      secretRef: 'secret',
      capabilities: const ProviderCapabilities(
        images: true,
        requiresPublicUrl: true,
      ),
    );
    final asset = MediaAsset(
      id: 'image',
      path: '/tmp/post.png',
      kind: MediaKind.image,
      mime: 'image/png',
      bytes: 10,
      modifiedAt: DateTime(2026),
    );
    final result = await InstagramAdapter().preflight(
      account: account,
      intent: PublishIntent(
        operationId: 'job',
        assets: [asset],
        caption: '',
        accounts: [account],
      ),
    );
    expect(result.failure?.kind, FailureKind.missingPublicUrl);
  });

  test('job recognizes partial success without rollback', () {
    final account = ConnectedAccount(
      id: 'account',
      provider: SocialProvider.bluesky,
      providerAccountId: 'did:plc:test',
      label: 'Bluesky',
      secretRef: 'secret',
      capabilities: const ProviderCapabilities(images: true),
    );
    final intent = PublishIntent(
      operationId: 'job',
      assets: const [],
      caption: '',
      accounts: [account],
    );
    final task = DestinationTask(
      id: 'task',
      jobId: 'job',
      provider: SocialProvider.bluesky,
      account: account,
      state: DestinationState.succeeded,
    );
    final failed = DestinationTask(
      id: 'task-2',
      jobId: 'job',
      provider: SocialProvider.bluesky,
      account: account,
      state: DestinationState.blocked,
    );
    final job = UploadJob(id: 'job', intent: intent, tasks: [task, failed]);
    expect(job.isComplete, isTrue);
    expect(job.partiallySucceeded, isTrue);
  });
}
