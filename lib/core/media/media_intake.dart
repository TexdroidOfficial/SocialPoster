import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import '../../features/media/domain/media_models.dart';
import '../errors/app_failure.dart';

typedef PickMediaFiles = Future<List<PlatformFile>> Function();

class MediaIntake {
  MediaIntake({this._picker});

  final PickMediaFiles? _picker;

  Future<List<MediaAsset>> pickAssets() async {
    final picker =
        _picker ??
        () => FilePicker.pickFiles(allowMultiple: true, type: FileType.media);
    final result = await picker();
    return Future.wait(
      result
          .where((file) => file.path != null)
          .map((file) => snapshot(file.path!)),
    );
  }

  Future<MediaAsset> snapshot(String path, {String? publicUrl}) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const AppFailure(
        FailureKind.fileUnavailable,
        'The selected media file is no longer available.',
      );
    }
    final stat = await file.stat();
    final mime = lookupMimeType(path) ?? 'application/octet-stream';
    final kind = mime.startsWith('video/')
        ? MediaKind.video
        : mime.startsWith('image/')
        ? MediaKind.image
        : null;
    if (kind == null) {
      throw const AppFailure(
        FailureKind.unsupportedMedia,
        'The selected file is not a supported image or video.',
      );
    }
    return MediaAsset(
      id: const Uuid().v4(),
      path: path,
      kind: kind,
      mime: mime,
      bytes: stat.size,
      modifiedAt: stat.modified,
      contentHash: await _hash(file),
      publicUrl: publicUrl,
    );
  }

  Future<void> verifyUnchanged(MediaAsset asset) async {
    final file = File(asset.path);
    if (!await file.exists()) {
      throw const AppFailure(
        FailureKind.fileUnavailable,
        'The media file is no longer available.',
      );
    }
    final stat = await file.stat();
    if (stat.size != asset.bytes || stat.modified != asset.modifiedAt) {
      throw const AppFailure(
        FailureKind.fileChanged,
        'The media file changed after it was selected. Revalidate it before publishing.',
      );
    }
  }

  Future<String> _hash(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
