import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/account_controller.dart';
import '../domain/account_models.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text('Accounts', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        const Text(
          'Connect provider accounts locally. Tokens remain in the OS secure store; only account metadata is persisted.',
          style: TextStyle(color: Color(0xffb8adbf)),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final provider in SocialProvider.values)
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(accountsProvider.notifier)
                    .addDemoAccount(provider),
                icon: const Icon(Icons.add),
                label: Text('Add ${provider.label}'),
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
