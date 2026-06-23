import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UploadStatus { pending, uploading, completed, failed }

class UploadTask {
  final String id;
  final String fileName;
  final int totalBytes;
  final int uploadedBytes;
  final UploadStatus status;
  final String? error;
  final bool isDuplicate;

  const UploadTask({
    required this.id,
    required this.fileName,
    required this.totalBytes,
    this.uploadedBytes = 0,
    this.status = UploadStatus.pending,
    this.error,
    this.isDuplicate = false,
  });

  UploadTask copyWith({
    int? uploadedBytes,
    UploadStatus? status,
    String? error,
    bool? isDuplicate,
  }) {
    return UploadTask(
      id: id,
      fileName: fileName,
      totalBytes: totalBytes,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      status: status ?? this.status,
      error: error,
      isDuplicate: isDuplicate ?? this.isDuplicate,
    );
  }
}

class UploadState {
  final List<UploadTask> queue;
  final bool isUploading;

  const UploadState({this.queue = const [], this.isUploading = false});

  UploadState copyWith({List<UploadTask>? queue, bool? isUploading}) {
    return UploadState(
      queue: queue ?? this.queue,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  UploadNotifier() : super(const UploadState());

  void clearAll() {
    state = const UploadState();
  }

  void removeTask(String id) {
    state = state.copyWith(
      queue: state.queue.where((t) => t.id != id).toList(),
    );
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((
  ref,
) {
  return UploadNotifier();
});
