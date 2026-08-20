import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../application/account_controller.dart';
import '../application/account_link_service.dart';
import '../domain/account_models.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  SocialProvider? _linkingProvider;

  Future<void> _linkAccount(SocialProvider provider) async {
    final credentials = await showDialog<LinkCredentials>(
      context: context,
      builder: (_) => _LinkAccountDialog(provider: provider),
    );
    if (credentials == null || !mounted) return;
    setState(() => _linkingProvider = provider);
    try {
      await ref
          .read(accountsProvider.notifier)
          .linkAccount(provider, credentials: credentials);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${provider.label} account linked.')),
        );
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _linkingProvider = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text('Accounts', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        const Text(
          'Authorization opens in your browser. Tokens are stored only in this device\'s secure credential store.',
          style: TextStyle(color: Color(0xffb8adbf)),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final provider in SocialProvider.values)
              OutlinedButton.icon(
                onPressed: _linkingProvider == null
                    ? () => _linkAccount(provider)
                    : null,
                icon: _linkingProvider == provider
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: Text('Link ${provider.label}'),
              ),
          ],
        ),
        const SizedBox(height: 28),
        if (accounts.isEmpty)
          const _EmptyCard(
            icon: Icons.hub_outlined,
            title: 'No connected accounts',
            message:
                'Add an account to make it available in the publish workspace.',
          )
        else
          ...accounts.map((account) => _AccountCard(account: account)),
      ],
    );
  }
}

class _LinkAccountDialog extends StatefulWidget {
  const _LinkAccountDialog({required this.provider});

  final SocialProvider provider;

  @override
  State<_LinkAccountDialog> createState() => _LinkAccountDialogState();
}

class _LinkAccountDialogState extends State<_LinkAccountDialog> {
  final _pds = TextEditingController(text: 'https://bsky.social');
  final _identifier = TextEditingController();
  final _appPassword = TextEditingController();

  @override
  void dispose() {
    _pds.dispose();
    _identifier.dispose();
    _appPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bluesky = widget.provider == SocialProvider.bluesky;
    return AlertDialog(
      title: Text('Link ${widget.provider.label}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bluesky
                    ? 'Use a Bluesky app password. It is sent directly over HTTPS and stored only in this device\'s secure credential store.'
                    : 'Your system browser will open for authorization. Vercel exchanges the authorization code and this device stores the tokens securely.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              if (bluesky) ...[
                _field(_pds, 'PDS service URL'),
                const SizedBox(height: 12),
                _field(_identifier, 'Handle or email'),
                const SizedBox(height: 12),
                _field(_appPassword, 'App password', obscureText: true),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            LinkCredentials(
              pds: _pds.text,
              identifier: _identifier.text,
              appPassword: _appPassword.text,
            ),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscureText = false,
  }) => TextField(
    controller: controller,
    obscureText: obscureText,
    decoration: InputDecoration(labelText: label),
  );
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.account});
  final ConnectedAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(account.provider.label.substring(0, 1)),
        ),
        title: Text(account.label),
        subtitle: Text('${account.provider.label}  •  ${account.status.name}'),
        trailing: IconButton(
          tooltip: 'Disconnect',
          onPressed: () =>
              ref.read(accountsProvider.notifier).disconnect(account),
          icon: const Icon(Icons.link_off_outlined),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 34),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message),
        ],
      ),
    ),
  );
}
