import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/media_controller.dart';
import '../domain/media_models.dart';

class MediaPage extends ConsumerWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(mediaControllerProvider);
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Media library',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(mediaControllerProvider.notifier).pick(),
              icon: const Icon(Icons.upload_file),
              label: const Text('Select files'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Assets are inspected before publishing. Source files are never modified or deleted.',
          style: TextStyle(color: Color(0xffb8adbf)),
        ),
        const SizedBox(height: 24),
        if (assets.isEmpty)
          const _MediaEmpty()
        else
          ...assets.map((asset) => _AssetTile(asset: asset)),
      ],
    );
  }
}

class _AssetTile extends ConsumerWidget {
  const _AssetTile({required this.asset});
  final MediaAsset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          asset.kind == MediaKind.video
              ? Icons.movie_outlined
              : Icons.image_outlined,
          size: 30,
        ),
        title: Text(asset.path.split(RegExp(r'[/\\]')).last),
        subtitle: Text('${asset.mime}  •  ${_formatBytes(asset.bytes)}'),
        trailing: IconButton(
          onPressed: () =>
              ref.read(mediaControllerProvider.notifier).remove(asset.id),
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) => bytes < 1000000
      ? '${(bytes / 1000).toStringAsFixed(1)} KB'
      : '${(bytes / 1000000).toStringAsFixed(1)} MB';
}

class _MediaEmpty extends StatelessWidget {
  const _MediaEmpty();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        children: [
          Icon(
            Icons.perm_media_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            'Your workspace is clear',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Select image or video files to begin.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
