import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engram_service.dart';
import '../models/engram_file.dart';
import '../widgets/gallery/gallery_view_model.dart';
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
  final List<FolderEntry> folders;
  final String folderPath;
  final GalleryGroupingMode groupingMode;

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
    this.folders = const [],
    this.folderPath = '',
    this.groupingMode = GalleryGroupingMode.allFiles,
  });

  /// Folder scope is what makes Engram return a single directory's direct
  /// children. Search deliberately escapes it: results must span every folder.
  bool get isFolderScoped =>
      groupingMode == GalleryGroupingMode.folders && searchQuery.isEmpty;

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
    List<FolderEntry>? folders,
    String? folderPath,
    GalleryGroupingMode? groupingMode,
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
      folders: folders ?? this.folders,
      folderPath: folderPath ?? this.folderPath,
      groupingMode: groupingMode ?? this.groupingMode,
    );
  }
}

class FileListNotifier extends StateNotifier<FileListState> {
  EngramService? _engram;
  bool _isLoggedIn = false;
  bool _didLoadInitial = false;
  static const _pageSize = 50;

  FileListNotifier(this._engram, this._isLoggedIn)
    : super(const FileListState());

  /// A replaced service means the data source changed — a reconfigured server
  /// URL invalidates the providers — so the listing the old one produced no
  /// longer describes anything and the initial load has to run again.
  void setEngram(EngramService engram) {
    if (identical(_engram, engram)) return;
    if (_engram != null) _didLoadInitial = false;
    _engram = engram;
    _loadInitialIfReady();
  }

  void setLoggedIn(bool isLoggedIn) {
    if (_isLoggedIn == isLoggedIn) return;
    _isLoggedIn = isLoggedIn;
    if (!isLoggedIn) {
      // This notifier outlives the session, so signing out has to drop the
      // listing explicitly. Without the reset, the next sign-in on this tab
      // renders the previous user's files and _didLoadInitial suppresses the
      // fetch that would have replaced them.
      _didLoadInitial = false;
      state = const FileListState();
      return;
    }
    _loadInitialIfReady();
  }

  void loadInitialIfReady() {
    _loadInitialIfReady();
  }

  void _loadInitialIfReady() {
    if (_didLoadInitial || !_isLoggedIn || _engram == null) return;
    _didLoadInitial = true;
    loadFiles();
    loadFolders();
    loadTags();
  }

  Future<void> loadFiles({bool append = false}) async {
    final engram = _engram;
    if (engram == null || !_isLoggedIn) return;
    state = state.copyWith(
      isLoading: !append,
      isLoadingMore: append,
      error: null,
    );
    try {
      final offset = append ? state.offset : 0;
      final folderScoped = state.isFolderScoped;
      final files = await engram.listFiles(
        offset: offset,
        limit: _pageSize,
        query: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        tags: state.selectedTags.toList(),
        fileType: state.selectedType,
        scope: folderScoped ? 'folder' : null,
        path: folderScoped ? state.folderPath : null,
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

  /// Fetches the current directory's subfolders. Engram returns the complete
  /// set, so the tree no longer depends on how many pages of files have been
  /// loaded. A failure here leaves the file list intact rather than blanking
  /// the gallery.
  Future<void> loadFolders() async {
    // Clearing is local state rather than a fetch, so it happens even when the
    // service is unavailable: stale folders must never outlive the scope that
    // produced them.
    if (!state.isFolderScoped) {
      if (state.folders.isNotEmpty) {
        state = state.copyWith(folders: const []);
      }
      return;
    }
    final engram = _engram;
    if (engram == null || !_isLoggedIn) return;
    try {
      final raw = await engram.listFolders(
        path: state.folderPath,
        query: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        tags: state.selectedTags.toList(),
        fileType: state.selectedType,
      );
      state = state.copyWith(folders: raw.map(FolderEntry.fromJson).toList());
    } catch (_) {}
  }

  /// Moves to a directory, or switches between folder and flat views. Both
  /// reload files and folders together so the two can never describe different
  /// directories.
  void setFolder({
    required GalleryGroupingMode groupingMode,
    required String folderPath,
  }) {
    final normalized = GalleryFolderPath(folderPath).path;
    if (state.groupingMode == groupingMode && state.folderPath == normalized) {
      return;
    }
    state = state.copyWith(
      groupingMode: groupingMode,
      folderPath: normalized,
      offset: 0,
    );
    loadFiles();
    loadFolders();
  }

  Future<void> loadTags() async {
    final engram = _engram;
    if (engram == null || !_isLoggedIn) return;
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
    loadFolders();
  }

  void setSelectedType(String? type) {
    state = state.copyWith(selectedType: type, offset: 0);
    loadFiles();
    loadFolders();
  }

  void setSelectedTags(Set<String> tags) {
    state = state.copyWith(selectedTags: tags, offset: 0);
    loadFiles();
    loadFolders();
  }

  void setRouteState({
    required String searchQuery,
    required String? selectedType,
    required Set<String> selectedTags,
    required GalleryGroupingMode groupingMode,
    required String folderPath,
  }) {
    final normalizedType = selectedType == 'all' ? null : selectedType;
    final normalizedPath = GalleryFolderPath(folderPath).path;
    if (state.searchQuery == searchQuery &&
        state.selectedType == normalizedType &&
        state.groupingMode == groupingMode &&
        state.folderPath == normalizedPath &&
        state.selectedTags.length == selectedTags.length &&
        state.selectedTags.containsAll(selectedTags)) {
      return;
    }
    state = state.copyWith(
      searchQuery: searchQuery,
      selectedType: normalizedType,
      selectedTags: selectedTags,
      groupingMode: groupingMode,
      folderPath: normalizedPath,
      offset: 0,
    );
    loadFiles();
    loadFolders();
  }

  void applyFilters(String? type, Set<String> tags) {
    state = state.copyWith(selectedType: type, selectedTags: tags, offset: 0);
    loadFiles();
    loadFolders();
  }

  void toggleTag(String name) {
    final updated = Set<String>.from(state.selectedTags);
    if (!updated.remove(name)) updated.add(name);
    state = state.copyWith(selectedTags: updated);
    loadFiles();
    loadFolders();
  }

  Future<void> invalidate() async {
    state = state.copyWith(refreshTrigger: state.refreshTrigger + 1);
    await Future.wait([loadFiles(), loadFolders(), loadTags()]);
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
      ref.read(appAuthProvider).isLoggedIn,
    );
    ref.listen(engramServiceProvider, (_, next) {
      next.whenData((engram) => notifier.setEngram(engram));
    });
    ref.listen(appAuthProvider.select((state) => state.isLoggedIn), (_, next) {
      notifier.setLoggedIn(next);
    });
    notifier.loadInitialIfReady();
    return notifier;
  },
);
