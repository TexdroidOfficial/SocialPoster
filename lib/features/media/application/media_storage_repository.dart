import '../domain/media_models.dart';

class LocalMediaRepository {
  Future<MediaAsset> upload(MediaAsset asset, String ownerId) async =>
      MediaAsset(
        id: asset.id,
        ownerId: ownerId,
        path: asset.path,
        kind: asset.kind,
        mime: asset.mime,
        bytes: asset.bytes,
        modifiedAt: asset.modifiedAt,
        contentHash: asset.contentHash,
        publicUrl: asset.publicUrl,
        retention: AssetRetention.staged,
      );

  Future<void> delete(MediaAsset asset) async {}

  Future<String> requireOwnerId() async => 'local-desktop';
}
