import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_intake.dart';
import '../domain/media_models.dart';

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
    state = [...state, ...await intake.pickAssets()];
  }

  Future<void> addPathForTest(String path, {String? publicUrl}) async {
    final intake = _intake ??= MediaIntake();
    state = [...state, await intake.snapshot(path, publicUrl: publicUrl)];
  }

  void remove(String id) =>
      state = state.where((asset) => asset.id != id).toList();

  void clear() => state = [];
}

final filePickerProvider = Provider<FilePicker>((_) => FilePicker.platform);
