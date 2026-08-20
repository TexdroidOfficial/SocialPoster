enum MediaKind { image, video }

enum AssetRetention { source, staged, temporary }

class MediaAsset {
  const MediaAsset({
    required this.id,
    this.ownerId,
    required this.path,
    required this.kind,
    required this.mime,
    required this.bytes,
    required this.modifiedAt,
    this.contentHash,
    this.publicUrl,
    this.retention = AssetRetention.source,
  });

  final String id;
  final String? ownerId;
  final String path;
  final MediaKind kind;
  final String mime;
  final int bytes;
  final DateTime modifiedAt;
  final String? contentHash;
  final String? publicUrl;
  final AssetRetention retention;

  bool get hasPublicHttpsUrl => publicUrl?.startsWith('https://') ?? false;
}
