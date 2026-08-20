import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/environment.dart';
import 'account_link_service.dart';
import 'local_account_store.dart';
import '../domain/account_models.dart';

final environmentProvider = appEnvironmentProvider;
final accountStoreProvider = Provider<AccountStore>((_) => LocalAccountStore());
final databaseProvider = accountStoreProvider;
final accountLinkServiceProvider = Provider<AccountLinkService>((ref) {
  return AccountLinkService(environment: ref.read(environmentProvider));
});

final accountsProvider =
    NotifierProvider<AccountsController, List<ConnectedAccount>>(
      AccountsController.new,
    );

class AccountsController extends Notifier<List<ConnectedAccount>> {
  @override
  List<ConnectedAccount> build() {
    Future<void>.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    state = await ref.read(accountStoreProvider).accounts();
  }

  Future<void> linkAccount(
    SocialProvider provider, {
    LinkCredentials credentials = const LinkCredentials(),
  }) async {
    final linked = await ref
        .read(accountLinkServiceProvider)
        .link(provider, credentials: credentials);
    final account = ConnectedAccount(
      id: linked.backendAccountId,
      ownerId: linked.ownerId,
      provider: linked.provider,
      providerAccountId: linked.providerAccountId,
      label: linked.label,
      backendAccountId: linked.backendAccountId,
      capabilities: linked.capabilities,
      serviceEndpoint: linked.serviceEndpoint,
      lastValidatedAt: DateTime.now(),
    );
    await ref.read(accountStoreProvider).upsertAccount(account);
    state = [...state.where((item) => item.id != account.id), account];
  }

  Future<void> disconnect(ConnectedAccount account) async {
    await ref.read(accountLinkServiceProvider).disconnect(account);
    await ref.read(accountStoreProvider).deleteAccount(account.id);
    state = state.where((item) => item.id != account.id).toList();
  }
}
