import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_poster/core/config/environment.dart';
import 'package:social_poster/features/accounts/application/account_controller.dart';
import 'package:social_poster/features/accounts/application/account_link_service.dart';
import 'package:social_poster/features/accounts/application/local_account_store.dart';
import 'package:social_poster/features/accounts/domain/account_models.dart';
import 'package:social_poster/features/accounts/presentation/accounts_page.dart';

class _FakeLinkService extends AccountLinkService {
  _FakeLinkService() : super(environment: const AppEnvironment());

  @override
  Future<LinkedAccountData> link(
    SocialProvider provider, {
    LinkCredentials credentials = const LinkCredentials(),
  }) async => LinkedAccountData(
    provider: provider,
    ownerId: 'user',
    providerAccountId: 'real-account-id',
    backendAccountId: 'backend-account-id',
    label: 'Linked account',
    capabilities: const ProviderCapabilities(images: true),
  );

  @override
  Future<void> disconnect(ConnectedAccount account) async {}
}

void main() {
  test(
    'linking stores backend account metadata without provider secrets',
    () async {
      final database = MemoryAccountStore();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          accountLinkServiceProvider.overrideWithValue(_FakeLinkService()),
        ],
      );
      addTearDown(() {
        container.dispose();
      });

      await container
          .read(accountsProvider.notifier)
          .linkAccount(SocialProvider.youtube);

      final account = container.read(accountsProvider).single;
      expect(account.providerAccountId, 'real-account-id');
      expect(account.label, 'Linked account');
      expect(account.label, isNot(contains('demo')));
      expect(await database.accounts(), hasLength(1));

      await container.read(accountsProvider.notifier).disconnect(account);
      expect(await database.accounts(), isEmpty);
    },
  );

  testWidgets('account page exposes real link actions', (tester) async {
    final database = MemoryAccountStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          accountLinkServiceProvider.overrideWithValue(_FakeLinkService()),
        ],
        child: const MaterialApp(home: AccountsPage()),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Link YouTube'),
      200,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Link YouTube'), findsOneWidget);
    expect(find.text('Link Instagram'), findsOneWidget);
    expect(find.text('Link TikTok'), findsOneWidget);
    expect(find.text('Link Bluesky'), findsOneWidget);
    expect(find.textContaining('demo'), findsNothing);
  });
}
