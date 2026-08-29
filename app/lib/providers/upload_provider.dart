import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/picked_file.dart';

import '../widgets/upload/upload_progress.dart';

class UploadState {
  final List<PickedFile> selectedFiles;
  final Map<String, UploadProgress> progressMap;
  final bool isUploading;

  const UploadState({
    this.selectedFiles = const [],
    this.progressMap = const {},
    this.isUploading = false,
  });

  UploadState copyWith({
    List<PickedFile>? selectedFiles,
    Map<String, UploadProgress>? progressMap,
    bool? isUploading,
  }) {
    return UploadState(
      selectedFiles: selectedFiles ?? this.selectedFiles,
      progressMap: progressMap ?? this.progressMap,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  UploadNotifier() : super(const UploadState());

  static String key(PickedFile f) =>
      '${f.relativePath ?? f.name}::${f.hashCode}';

  void addFiles(List<PickedFile> files) {
    final updated = Map<String, UploadProgress>.from(state.progressMap);
    for (final f in files) {
      final k = key(f);
      if (!updated.containsKey(k)) {
        updated[k] = const UploadProgress(status: 'Pending');
      }
    }
    state = state.copyWith(
      selectedFiles: [...state.selectedFiles, ...files],
      progressMap: updated,
    );
  }

  void removeFile(String fileKey) {
    final files = state.selectedFiles.where((f) => key(f) != fileKey).toList();
    final progress = Map<String, UploadProgress>.from(state.progressMap)
      ..remove(fileKey);
    state = state.copyWith(selectedFiles: files, progressMap: progress);
  }

  void setProgress(String fileKey, UploadProgress progress) {
    final updated = Map<String, UploadProgress>.from(state.progressMap)
      ..[fileKey] = progress;
    state = state.copyWith(progressMap: updated);
  }

  void setUploading(bool value) {
    state = state.copyWith(isUploading: value);
  }

  void clearAll() {
    state = const UploadState();
  }

  void clearCompleted() {
    final remaining = <PickedFile>[];
    final progress = <String, UploadProgress>{};
    for (final f in state.selectedFiles) {
      final k = key(f);
      final p = state.progressMap[k];
      if (p == null || (!p.done && !p.error)) {
        remaining.add(f);
        if (p != null) progress[k] = p;
      }
    }
    state = UploadState(
      selectedFiles: remaining,
      progressMap: progress,
      isUploading: false,
    );
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((
  ref,
) {
  return UploadNotifier();
});
