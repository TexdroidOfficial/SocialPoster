import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/environment.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/security/secret_store.dart';
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

  Future<void> addDemoAccount(SocialProvider provider) async {
    final id = const Uuid().v4();
    final capabilities = switch (provider) {
      SocialProvider.youtube => const ProviderCapabilities(
        videos: true,
        thumbnail: true,
      ),
      SocialProvider.instagram => const ProviderCapabilities(
        images: true,
        videos: true,
        carousel: true,
        requiresPublicUrl: true,
      ),
      SocialProvider.tiktok => const ProviderCapabilities(
        images: true,
        videos: true,
        videoTransfer: true,
        photoTransfer: true,
      ),
      SocialProvider.bluesky => const ProviderCapabilities(
        images: true,
        videos: true,
        carousel: true,
      ),
    };
    final account = ConnectedAccount(
      id: id,
      provider: provider,
      providerAccountId: 'local-demo-$id',
      label: '${provider.label} demo account',
      secretRef: 'account/$id',
      capabilities: capabilities,
    );
    await ref.read(secretStoreProvider).write(account.secretRef, 'demo-token');
    ref
        .read(databaseProvider)
        .insertAccount(
          values: {
            'id': account.id,
            'provider': account.provider.name,
            'provider_account_id': account.providerAccountId,
            'label': account.label,
            'secret_ref': account.secretRef,
            'capabilities': jsonEncode(_capabilityMap(capabilities)),
            'status': account.status.name,
            'last_validated_at': DateTime.now().toIso8601String(),
          },
        );
    state = [...state, account];
  }

  Future<void> disconnect(ConnectedAccount account) async {
    await ref.read(secretStoreProvider).delete(account.secretRef);
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
