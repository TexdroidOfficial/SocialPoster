import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_poster/core/config/environment.dart';
import 'package:social_poster/core/persistence/app_database.dart';
import 'package:social_poster/core/security/oauth.dart';
import 'package:social_poster/core/security/secret_store.dart';
import 'package:social_poster/features/accounts/application/account_controller.dart';
import 'package:social_poster/features/accounts/application/account_link_service.dart';
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
    providerAccountId: 'real-account-id',
    label: 'Linked account',
    tokens: const OAuthTokens(accessToken: 'access-token'),
    capabilities: const ProviderCapabilities(images: true),
  );
}

void main() {
  test(
    'linking stores provider metadata and secrets without demo values',
    () async {
      final database = AppDatabase.inMemory();
      final secrets = MemorySecretStore();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          secretStoreProvider.overrideWithValue(secrets),
          accountLinkServiceProvider.overrideWithValue(_FakeLinkService()),
        ],
      );
      addTearDown(() {
        container.dispose();
        database.close();
      });

      await container
          .read(accountsProvider.notifier)
          .linkAccount(SocialProvider.youtube);

      final account = container.read(accountsProvider).single;
      expect(account.providerAccountId, 'real-account-id');
      expect(account.label, 'Linked account');
      expect(account.label, isNot(contains('demo')));
      expect(await secrets.read(account.secretRef), contains('access-token'));
      expect(database.accounts(), hasLength(1));

      await container.read(accountsProvider.notifier).disconnect(account);
      expect(database.accounts(), isEmpty);
      expect(await secrets.read(account.secretRef), isNull);
    },
  );

  testWidgets('account page exposes real link actions', (tester) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          accountLinkServiceProvider.overrideWithValue(_FakeLinkService()),
        ],
        child: const MaterialApp(home: AccountsPage()),
      ),
    );

    expect(find.text('Link YouTube'), findsOneWidget);
    expect(find.text('Link Instagram'), findsOneWidget);
    expect(find.text('Link TikTok'), findsOneWidget);
    expect(find.text('Link Bluesky'), findsOneWidget);
    expect(find.textContaining('demo'), findsNothing);
  });
}
