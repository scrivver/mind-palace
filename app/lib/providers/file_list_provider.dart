import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engram_service.dart';
import '../models/engram_file.dart';
import 'service_providers.dart';

class FileListState {
  final List<EngramFile> files;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String searchQuery;
  final String? selectedType;
  final int offset;
  final bool hasMore;
  final int refreshTrigger;
  final List<Map<String, dynamic>> availableTags;
  final Set<String> selectedTags;

  const FileListState({
    this.files = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.searchQuery = '',
    this.selectedType,
    this.offset = 0,
    this.hasMore = false,
    this.refreshTrigger = 0,
    this.availableTags = const [],
    this.selectedTags = const {},
  });

  static const _sentinel = Object();

  FileListState copyWith({
    List<EngramFile>? files,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error = _sentinel,
    String? searchQuery,
    Object? selectedType = _sentinel,
    int? offset,
    bool? hasMore,
    int? refreshTrigger,
    List<Map<String, dynamic>>? availableTags,
    Set<String>? selectedTags,
  }) {
    return FileListState(
      files: files ?? this.files,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: identical(error, _sentinel) ? this.error : error as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedType: identical(selectedType, _sentinel)
          ? this.selectedType
          : selectedType as String?,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      refreshTrigger: refreshTrigger ?? this.refreshTrigger,
      availableTags: availableTags ?? this.availableTags,
      selectedTags: selectedTags ?? this.selectedTags,
    );
  }
}

class FileListNotifier extends StateNotifier<FileListState> {
  EngramService? _engram;
  static const _pageSize = 50;

  FileListNotifier(this._engram) : super(const FileListState());

  void setEngram(EngramService engram) {
    _engram = engram;
    loadFiles();
    loadTags();
  }

  Future<void> loadFiles({bool append = false}) async {
    final engram = _engram;
    if (engram == null) return;
    state = state.copyWith(
      isLoading: !append,
      isLoadingMore: append,
      error: null,
    );
    try {
      final offset = append ? state.offset : 0;
      final files = await engram.listFiles(
        offset: offset,
        limit: _pageSize,
        query: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        tags: state.selectedTags.toList(),
        fileType: state.selectedType,
      );
      state = state.copyWith(
        files: append ? [...state.files, ...files] : files,
        isLoading: false,
        isLoadingMore: false,
        offset: offset + files.length,
        hasMore: files.length == _pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadTags() async {
    final engram = _engram;
    if (engram == null) return;
    try {
      final tags = await engram.listTags();
      final names = tags.map((t) => t['name'] as String).toSet();
      state = state.copyWith(
        availableTags: tags,
        selectedTags: state.selectedTags.where(names.contains).toSet(),
      );
    } catch (_) {}
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, offset: 0);
    loadFiles();
  }

  void setSelectedType(String? type) {
    state = state.copyWith(selectedType: type, offset: 0);
    loadFiles();
  }

  void setSelectedTags(Set<String> tags) {
    state = state.copyWith(selectedTags: tags);
    loadFiles();
  }

  void setRouteState({
    required String searchQuery,
    required String? selectedType,
    required Set<String> selectedTags,
  }) {
    final normalizedType = selectedType == 'all' ? null : selectedType;
    if (state.searchQuery == searchQuery &&
        state.selectedType == normalizedType &&
        state.selectedTags.length == selectedTags.length &&
        state.selectedTags.containsAll(selectedTags)) {
      return;
    }
    state = state.copyWith(
      searchQuery: searchQuery,
      selectedType: normalizedType,
      selectedTags: selectedTags,
      offset: 0,
    );
    loadFiles();
  }

  void applyFilters(String? type, Set<String> tags) {
    state = state.copyWith(selectedType: type, selectedTags: tags);
    loadFiles();
  }

  void toggleTag(String name) {
    final updated = Set<String>.from(state.selectedTags);
    if (!updated.remove(name)) updated.add(name);
    state = state.copyWith(selectedTags: updated);
    loadFiles();
  }

  Future<void> invalidate() async {
    state = state.copyWith(refreshTrigger: state.refreshTrigger + 1);
    await Future.wait([loadFiles(), loadTags()]);
  }

  void loadMore() {
    if (!state.isLoadingMore && state.hasMore) {
      loadFiles(append: true);
    }
  }
}

final fileListProvider = StateNotifierProvider<FileListNotifier, FileListState>(
  (ref) {
    final notifier = FileListNotifier(
      ref.read(engramServiceProvider).valueOrNull,
    );
    ref.listen(engramServiceProvider, (_, next) {
      next.whenData((engram) => notifier.setEngram(engram));
    });
    return notifier;
  },
);
