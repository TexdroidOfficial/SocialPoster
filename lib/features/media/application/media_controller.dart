import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_intake.dart';
import '../domain/media_models.dart';
import 'media_storage_repository.dart';

final mediaControllerProvider =
    NotifierProvider<MediaController, List<MediaAsset>>(MediaController.new);

class MediaController extends Notifier<List<MediaAsset>> {
  MediaIntake? _intake;

  @override
  List<MediaAsset> build() {
    return [];
  }

  Future<void> pick() async {
    final intake = _intake ??= MediaIntake();
    final picked = await intake.pickAssets();
    final repository = ref.read(mediaStorageRepositoryProvider);
    final ownerId = await repository.requireOwnerId();
    final uploaded = <MediaAsset>[];
    for (final asset in picked) {
      uploaded.add(await repository.upload(asset, ownerId));
    }
    state = [...state, ...uploaded];
  }

  Future<void> addPathForTest(String path, {String? publicUrl}) async {
    final intake = _intake ??= MediaIntake();
    state = [...state, await intake.snapshot(path, publicUrl: publicUrl)];
  }

  Future<void> remove(String id) async {
    final asset = state.firstWhere((item) => item.id == id);
    await ref.read(mediaStorageRepositoryProvider).delete(asset);
    state = state.where((item) => item.id != id).toList();
  }

  Future<void> clear() async {
    final repository = ref.read(mediaStorageRepositoryProvider);
    for (final asset in state) {
      await repository.delete(asset);
    }
    state = [];
  }
}

final filePickerProvider = Provider<PickMediaFiles>(
  (_) =>
      () => FilePicker.pickFiles(allowMultiple: true, type: FileType.media),
);

final mediaStorageRepositoryProvider = Provider<LocalMediaRepository>(
  (_) => LocalMediaRepository(),
);
