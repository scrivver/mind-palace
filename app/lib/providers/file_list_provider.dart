import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engram_service.dart';
import '../models/engram_file.dart';
import 'service_providers.dart';

class FileListState {
  final List<EngramFile> files;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String? selectedType;
  final int offset;
  final bool hasMore;
  final int refreshTrigger;

  const FileListState({
    this.files = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedType,
    this.offset = 0,
    this.hasMore = false,
    this.refreshTrigger = 0,
  });

  FileListState copyWith({
    List<EngramFile>? files,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? selectedType,
    int? offset,
    bool? hasMore,
    int? refreshTrigger,
  }) {
    return FileListState(
      files: files ?? this.files,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedType: selectedType,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      refreshTrigger: refreshTrigger ?? this.refreshTrigger,
    );
  }
}

class FileListNotifier extends StateNotifier<FileListState> {
  final EngramService? _engram;
  static const _pageSize = 50;

  FileListNotifier(this._engram) : super(const FileListState());

  Future<void> loadFiles({bool append = false}) async {
    final engram = _engram;
    if (engram == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final offset = append ? state.offset : 0;
      final files = await engram.listFiles(
        offset: offset,
        limit: _pageSize,
        query: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        fileType: state.selectedType,
      );
      state = state.copyWith(
        files: append ? [...state.files, ...files] : files,
        isLoading: false,
        offset: offset + files.length,
        hasMore: files.length == _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, offset: 0);
    loadFiles();
  }

  void setSelectedType(String? type) {
    state = state.copyWith(selectedType: type, offset: 0);
    loadFiles();
  }

  void invalidate() {
    state = state.copyWith(refreshTrigger: state.refreshTrigger + 1);
    loadFiles();
  }

  void loadMore() {
    if (!state.isLoading && state.hasMore) {
      loadFiles(append: true);
    }
  }
}

final fileListProvider =
    StateNotifierProvider<FileListNotifier, FileListState>((ref) {
  final engram = ref.watch(engramServiceProvider).valueOrNull;
  return FileListNotifier(engram);
});
