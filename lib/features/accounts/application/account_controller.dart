import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/environment.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/security/secret_store.dart';
import '../../../core/security/token_manager.dart';
import 'account_link_service.dart';
import '../domain/account_models.dart';

final environmentProvider = Provider<AppEnvironment>(
  (_) => const AppEnvironment(),
);
final databaseProvider = Provider<AppDatabase>(
  (_) => throw UnimplementedError(),
);
final secretStoreProvider = Provider<SecretStore>(
  (_) => throw UnimplementedError(),
);
final accountLinkServiceProvider = Provider<AccountLinkService>(
  (ref) => AccountLinkService(environment: ref.read(environmentProvider)),
);

final accountsProvider =
    NotifierProvider<AccountsController, List<ConnectedAccount>>(
      AccountsController.new,
    );

class AccountsController extends Notifier<List<ConnectedAccount>> {
  @override
  List<ConnectedAccount> build() {
    final rows = ref.read(databaseProvider).accounts();
    return rows.map(_fromRow).toList();
  }

  Future<void> linkAccount(
    SocialProvider provider, {
    LinkCredentials credentials = const LinkCredentials(),
  }) async {
    final linked = await ref
        .read(accountLinkServiceProvider)
        .link(provider, credentials: credentials);
    final id = const Uuid().v4();
    final account = ConnectedAccount(
      id: id,
      provider: linked.provider,
      providerAccountId: linked.providerAccountId,
      label: linked.label,
      secretRef: 'account/$id',
      capabilities: linked.capabilities,
      serviceEndpoint: linked.serviceEndpoint,
    );
    await TokenManager(ref.read(secretStoreProvider))
        .write(account.secretRef, linked.tokens);
    ref
        .read(databaseProvider)
        .insertAccount(
          values: {
            'id': account.id,
            'provider': account.provider.name,
            'provider_account_id': account.providerAccountId,
            'label': account.label,
            'secret_ref': account.secretRef,
            'capabilities': jsonEncode(_capabilityMap(linked.capabilities)),
            'status': account.status.name,
            'last_validated_at': DateTime.now().toIso8601String(),
            'service_endpoint': account.serviceEndpoint,
          },
        );
    state = [...state, account];
  }

  Future<void> disconnect(ConnectedAccount account) async {
    await ref.read(secretStoreProvider).delete(account.secretRef);
    ref.read(databaseProvider).deleteAccount(account.id);
    state = state.where((item) => item.id != account.id).toList();
  }

  ConnectedAccount _fromRow(Map<String, Object?> row) {
    final capabilities = Map<String, dynamic>.from(
      jsonDecode(row['capabilities']! as String) as Map,
    );
    return ConnectedAccount(
      id: row['id']! as String,
      provider: SocialProvider.values.byName(row['provider']! as String),
      providerAccountId: row['provider_account_id']! as String,
      label: row['label']! as String,
      secretRef: row['secret_ref']! as String,
      capabilities: ProviderCapabilities(
        images: capabilities['images'] as bool? ?? false,
        videos: capabilities['videos'] as bool? ?? false,
        carousel: capabilities['carousel'] as bool? ?? false,
        thumbnail: capabilities['thumbnail'] as bool? ?? false,
        requiresPublicUrl: capabilities['requiresPublicUrl'] as bool? ?? false,
        videoTransfer: capabilities['videoTransfer'] as bool? ?? false,
        photoTransfer: capabilities['photoTransfer'] as bool? ?? false,
      ),
      serviceEndpoint: row['service_endpoint'] as String?,
      status: AccountStatus.values.byName(row['status']! as String),
      lastValidatedAt: row['last_validated_at'] == null
          ? null
          : DateTime.parse(row['last_validated_at']! as String),
    );
  }

  Map<String, bool> _capabilityMap(ProviderCapabilities capabilities) => {
    'images': capabilities.images,
    'videos': capabilities.videos,
    'carousel': capabilities.carousel,
    'thumbnail': capabilities.thumbnail,
    'requiresPublicUrl': capabilities.requiresPublicUrl,
    'videoTransfer': capabilities.videoTransfer,
    'photoTransfer': capabilities.photoTransfer,
  };
}
