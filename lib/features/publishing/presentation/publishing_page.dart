import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/application/account_controller.dart';
import '../../accounts/domain/account_models.dart';
import '../../media/application/media_controller.dart';
import '../application/publishing_controller.dart';
import '../domain/publish_models.dart';

class PublishingPage extends ConsumerStatefulWidget {
  const PublishingPage({super.key});

  @override
  ConsumerState<PublishingPage> createState() => _PublishingPageState();
}

class _PublishingPageState extends ConsumerState<PublishingPage> {
  final _captionController = TextEditingController();
  final _videoTitleController = TextEditingController();
  final _selectedAccounts = <String>{};

  @override
  void dispose() {
    _captionController.dispose();
    _videoTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(mediaControllerProvider);
    final accounts = ref.watch(accountsProvider);
    final publishing = ref.watch(publishingControllerProvider);
    final youtubeSelected = accounts.any(
      (account) =>
          account.provider == SocialProvider.youtube &&
          _selectedAccounts.contains(account.id),
    );
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text('Social Poster', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        const Text(
          'All in one social media automatized poster. Unsupported targets stay visible instead of being silently skipped.',
          style: TextStyle(color: Color(0xffb8adbf)),
        ),
        const SizedBox(height: 26),
        _Section(
          title: '1  Choose media',
          child: assets.isEmpty
              ? _ActionPrompt(
                  onPressed: () =>
                      ref.read(mediaControllerProvider.notifier).pick(),
                  label: 'Select image or video files',
                  icon: Icons.upload_file,
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: assets
                      .map(
                        (asset) => Chip(
                          label: Text(asset.path.split(RegExp(r'[/\\]')).last),
                          onDeleted: () => ref
                              .read(mediaControllerProvider.notifier)
                              .remove(asset.id),
                        ),
                      )
                      .toList(),
                ),
        ),
        _Section(
          title: '2  Write the post',
          child: Column(
            children: [
              TextField(
                controller: _captionController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Write a caption or description',
                ),
              ),
              if (youtubeSelected) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('youtube-video-title'),
                  controller: _videoTitleController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'YouTube video title',
                    hintText: 'Give your video a title',
                    prefixIcon: Icon(Icons.ondemand_video_outlined),
                  ),
                ),
              ],
            ],
          ),
        ),
        _Section(
          title: '3  Select destinations',
          child: accounts.isEmpty
              ? const _Notice(
                  message: 'No accounts connected yet. Add them from Accounts.',
                )
              : Column(
                  children: accounts
                      .map(
                        (account) => _AccountSelector(
                          account: account,
                          selected: _selectedAccounts.contains(account.id),
                          onChanged: (selected) => setState(
                            () => selected
                                ? _selectedAccounts.add(account.id)
                                : _selectedAccounts.remove(account.id),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: publishing.isPublishing
              ? () => ref.read(publishingControllerProvider.notifier).cancel()
              : _canPublish(assets, accounts)
              ? _publish
              : null,
          icon: Icon(
            publishing.isPublishing ? Icons.stop_circle_outlined : Icons.send,
          ),
          label: Text(
            publishing.isPublishing
                ? 'Cancel publishing'
                : 'Run preflight and publish',
          ),
        ),
        if (publishing.job != null) ...[
          const SizedBox(height: 28),
          _JobCard(job: publishing.job!),
        ],
      ],
    );
  }

  bool _canPublish(List assets, List<ConnectedAccount> accounts) =>
      assets.isNotEmpty &&
      accounts.any((account) => _selectedAccounts.contains(account.id));

  Future<void> _publish() async {
    final assets = ref.read(mediaControllerProvider);
    final accounts = ref.read(accountsProvider);
    final selectedAccounts = accounts
        .where((account) => _selectedAccounts.contains(account.id))
        .toList();
    final youtubeSelected = selectedAccounts.any(
      (account) => account.provider == SocialProvider.youtube,
    );
    await ref
        .read(publishingControllerProvider.notifier)
        .publish(
          assets: assets,
          caption: _captionController.text.trim(),
          videoTitle:
              !youtubeSelected || _videoTitleController.text.trim().isEmpty
              ? null
              : _videoTitleController.text.trim(),
          accounts: selectedAccounts,
        );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _ActionPrompt extends StatelessWidget {
  const _ActionPrompt({
    required this.onPressed,
    required this.label,
    required this.icon,
  });
  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.all(18),
      alignment: Alignment.centerLeft,
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _AccountSelector extends StatelessWidget {
  const _AccountSelector({
    required this.account,
    required this.selected,
    required this.onChanged,
  });
  final ConnectedAccount account;
  final bool selected;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => CheckboxListTile(
    value: selected,
    onChanged: (value) => onChanged(value ?? false),
    contentPadding: EdgeInsets.zero,
    title: Text(account.label),
    subtitle: Text(account.provider.label),
    secondary: const Icon(Icons.account_circle_outlined),
  );
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});
  final UploadJob job;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.partiallySucceeded
                      ? 'Partially published'
                      : job.isComplete
                      ? 'Publish complete'
                      : 'Publishing',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${job.tasks.where((task) => task.state == DestinationState.succeeded).length}/${job.tasks.length}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...job.tasks.map((task) => _TaskRow(task: task)),
        ],
      ),
    ),
  );
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});
  final DestinationTask task;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(_icon, color: _color(context)),
    title: Text('${task.provider.label}  •  ${task.account.label}'),
    subtitle: Text(
      task.failure?.message ??
          '${task.state.name}  •  ${(task.progress * 100).round()}%',
    ),
  );
  IconData get _icon => switch (task.state) {
    DestinationState.succeeded => Icons.check_circle_outline,
    DestinationState.blocked => Icons.block,
    DestinationState.failed ||
    DestinationState.needsReauth => Icons.error_outline,
    _ => Icons.timelapse,
  };
  Color _color(BuildContext context) => switch (task.state) {
    DestinationState.succeeded => Colors.green,
    DestinationState.blocked => Colors.orange,
    DestinationState.failed ||
    DestinationState.needsReauth => Theme.of(context).colorScheme.error,
    _ => Theme.of(context).colorScheme.primary,
  };
}
