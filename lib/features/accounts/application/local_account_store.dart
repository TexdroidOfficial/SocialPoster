import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/account_models.dart';

abstract interface class AccountStore {
  Future<List<ConnectedAccount>> accounts();
  Future<void> upsertAccount(ConnectedAccount account);
  Future<void> deleteAccount(String accountId);
}

class LocalAccountStore implements AccountStore {
  LocalAccountStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'connected_accounts';
  final FlutterSecureStorage _storage;

  @override
  Future<List<ConnectedAccount>> accounts() async {
    final encoded = await _storage.read(key: _key);
    if (encoded == null || encoded.isEmpty) return const [];
    final values = jsonDecode(encoded);
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => _fromJson(Map<String, dynamic>.from(value)))
        .toList();
  }

  @override
  Future<void> upsertAccount(ConnectedAccount account) async {
    final values = await accounts();
    final updated = [
      ...values.where((value) => value.id != account.id),
      account,
    ];
    await _storage.write(
      key: _key,
      value: jsonEncode(updated.map(_toJson).toList()),
    );
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    final values = await accounts();
    await _storage.write(
      key: _key,
      value: jsonEncode(
        values.where((value) => value.id != accountId).map(_toJson).toList(),
      ),
    );
  }

  Map<String, dynamic> _toJson(ConnectedAccount account) => {
    'id': account.id,
    'ownerId': account.ownerId,
    'provider': account.provider.name,
    'providerAccountId': account.providerAccountId,
    'label': account.label,
    'backendAccountId': account.backendAccountId,
    'capabilities': {
      'images': account.capabilities.images,
      'videos': account.capabilities.videos,
      'carousel': account.capabilities.carousel,
      'thumbnail': account.capabilities.thumbnail,
      'requiresPublicUrl': account.capabilities.requiresPublicUrl,
      'videoTransfer': account.capabilities.videoTransfer,
      'photoTransfer': account.capabilities.photoTransfer,
    },
    'serviceEndpoint': account.serviceEndpoint,
    'status': account.status.name,
    'lastValidatedAt': account.lastValidatedAt?.toIso8601String(),
  };

  ConnectedAccount _fromJson(Map<String, dynamic> data) {
    final capabilities = Map<String, dynamic>.from(
      (data['capabilities'] as Map?) ?? const {},
    );
    return ConnectedAccount(
      id: data['id'] as String,
      ownerId: data['ownerId'] as String,
      provider: SocialProvider.values.byName(data['provider'] as String),
      providerAccountId: data['providerAccountId'] as String,
      label: data['label'] as String,
      backendAccountId: data['backendAccountId'] as String,
      capabilities: ProviderCapabilities(
        images: capabilities['images'] as bool? ?? false,
        videos: capabilities['videos'] as bool? ?? false,
        carousel: capabilities['carousel'] as bool? ?? false,
        thumbnail: capabilities['thumbnail'] as bool? ?? false,
        requiresPublicUrl: capabilities['requiresPublicUrl'] as bool? ?? false,
        videoTransfer: capabilities['videoTransfer'] as bool? ?? false,
        photoTransfer: capabilities['photoTransfer'] as bool? ?? false,
      ),
      serviceEndpoint: data['serviceEndpoint'] as String?,
      status: AccountStatus.values.byName(data['status'] as String),
      lastValidatedAt: data['lastValidatedAt'] == null
          ? null
          : DateTime.parse(data['lastValidatedAt'] as String),
    );
  }
}

class MemoryAccountStore implements AccountStore {
  final Map<String, ConnectedAccount> _accounts = {};

  @override
  Future<List<ConnectedAccount>> accounts() async => _accounts.values.toList();

  @override
  Future<void> upsertAccount(ConnectedAccount account) async {
    _accounts[account.id] = account;
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    _accounts.remove(accountId);
  }
}
