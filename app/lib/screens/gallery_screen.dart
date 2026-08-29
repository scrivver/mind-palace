import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/engram_file.dart';
import '../providers/file_list_provider.dart';
import '../providers/service_providers.dart';
import '../reliquary_service.dart';
import '../widgets/gallery/file_row.dart';
import '../widgets/gallery/file_tile.dart';
import '../widgets/gallery/filter_dropdown_panel.dart';
import '../widgets/gallery/folder_row.dart';
import '../widgets/gallery/folder_tile.dart';
import '../widgets/gallery/gallery_view_model.dart';
import '../widgets/gallery/quick_filter_chip.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToUpload;
  final void Function(EngramFile file) onOpenDetail;
  final String initialSearchQuery;
  final String? initialType;
  final Set<String> initialTags;
  final GalleryViewMode initialViewMode;
  final GalleryGroupingMode initialGroupingMode;
  final String initialFolderPath;
  final void Function({
    required String searchQuery,
    required String? selectedType,
    required Set<String> selectedTags,
    required GalleryViewMode viewMode,
    required GalleryGroupingMode groupingMode,
    required String folderPath,
  })?
  onRouteStateChanged;
  final int refreshTrigger;

  const GalleryScreen({
    super.key,
    this.onNavigateToUpload,
    required this.onOpenDetail,
    this.initialSearchQuery = '',
    this.initialType,
    this.initialTags = const {},
    this.initialViewMode = GalleryViewMode.grid,
    this.initialGroupingMode = GalleryGroupingMode.allFiles,
    this.initialFolderPath = '',
    this.onRouteStateChanged,
    required this.refreshTrigger,
  });

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  final ScrollController _scrollCtrl = ScrollController();
  late GalleryViewMode _viewMode;
  late GalleryGroupingMode _groupingMode;
  late GalleryFolderPath _folderPath;

  static const _fileTypes = <({String key, String label, IconData icon})>[
    (key: 'all', label: 'All Files', icon: Icons.grid_view),
    (key: 'image', label: 'Images', icon: Icons.image),
    (key: 'video', label: 'Video', icon: Icons.videocam),
    (key: 'audio', label: 'Audio', icon: Icons.audiotrack),
    (key: 'pdf', label: 'PDF', icon: Icons.picture_as_pdf),
    (key: 'other', label: 'Other', icon: Icons.insert_drive_file),
  ];

  final GlobalKey _filterButtonKey = GlobalKey();
  OverlayEntry? _filterDropdownOverlay;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialSearchQuery;
    _viewMode = widget.initialViewMode;
    _groupingMode = widget.initialGroupingMode;
    _folderPath = GalleryFolderPath(widget.initialFolderPath);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncRouteStateToProvider();
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(GalleryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      ref.read(fileListProvider.notifier).invalidate();
    }
    if (widget.initialSearchQuery != oldWidget.initialSearchQuery ||
        widget.initialType != oldWidget.initialType ||
        widget.initialTags.length != oldWidget.initialTags.length ||
        !widget.initialTags.containsAll(oldWidget.initialTags)) {
      _searchCtrl.text = widget.initialSearchQuery;
      _syncRouteStateToProvider();
    }
    if (widget.initialViewMode != oldWidget.initialViewMode ||
        widget.initialGroupingMode != oldWidget.initialGroupingMode ||
        widget.initialFolderPath != oldWidget.initialFolderPath) {
      _viewMode = widget.initialViewMode;
      _groupingMode = widget.initialGroupingMode;
      _folderPath = GalleryFolderPath(widget.initialFolderPath);
      _syncFolderStateToProvider();
    }
  }

  void _syncRouteStateToProvider() {
    ref
        .read(fileListProvider.notifier)
        .setRouteState(
          searchQuery: widget.initialSearchQuery.trim(),
          selectedType: widget.initialType,
          selectedTags: widget.initialTags,
          groupingMode: _groupingMode,
          folderPath: _folderPath.path,
        );
  }

  void _syncFolderStateToProvider() {
    ref
        .read(fileListProvider.notifier)
        .setFolder(groupingMode: _groupingMode, folderPath: _folderPath.path);
  }

  void _updateRouteState({
    String? searchQuery,
    String? selectedType,
    Set<String>? selectedTags,
    GalleryViewMode? viewMode,
    GalleryGroupingMode? groupingMode,
    String? folderPath,
  }) {
    final state = ref.read(fileListProvider);
    widget.onRouteStateChanged?.call(
      searchQuery: searchQuery ?? state.searchQuery,
      selectedType: selectedType ?? state.selectedType,
      selectedTags: selectedTags ?? state.selectedTags,
      viewMode: viewMode ?? _viewMode,
      groupingMode: groupingMode ?? _groupingMode,
      folderPath: folderPath ?? _folderPath.path,
    );
  }

  void _setViewMode(GalleryViewMode mode) {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    _updateRouteState(viewMode: mode);
  }

  void _setGroupingMode(GalleryGroupingMode mode) {
    if (_groupingMode == mode) return;
    setState(() => _groupingMode = mode);
    _syncFolderStateToProvider();
    _updateRouteState(groupingMode: mode);
  }

  void _openFolder(String path) {
    final next = GalleryFolderPath(path);
    setState(() => _folderPath = next);
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    _syncFolderStateToProvider();
    _updateRouteState(folderPath: next.path);
  }

  void _goUpFolder() {
    final next = _folderPath.parent();
    setState(() => _folderPath = next);
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    _syncFolderStateToProvider();
    _updateRouteState(folderPath: next.path);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _closeFilterDropdown();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final query = value.trim();
      ref.read(fileListProvider.notifier).setSearchQuery(query);
      _updateRouteState(searchQuery: query);
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(fileListProvider.notifier).loadMore();
    }
  }

  void _toggleTag(String name) {
    final current = ref.read(fileListProvider).selectedTags;
    final updated = Set<String>.from(current);
    if (!updated.remove(name)) updated.add(name);
    ref.read(fileListProvider.notifier).setSelectedTags(updated);
    _updateRouteState(selectedTags: updated);
  }

  void _openFilterDropdown(BuildContext context) {
    final renderBox =
        _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    const dropdownWidth = 288.0;
    final state = ref.read(fileListProvider);

    _filterDropdownOverlay = OverlayEntry(
      builder: (ctx) {
        return GestureDetector(
          onTap: _closeFilterDropdown,
          behavior: HitTestBehavior.opaque,
          child: Material(
            color: Colors.black26,
            child: Stack(
              children: [
                Positioned(
                  left: offset.dx,
                  top: offset.dy + renderBox.size.height + 4,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surface,
                    surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
                    child: SizedBox(
                      width: dropdownWidth,
                      child: FilterDropdownPanel(
                        fileTypes: _fileTypes,
                        initialSelectedTags: state.selectedTags,
                        initialTypeFilter: state.selectedType,
                        availableTags: state.availableTags,
                        onApply: (type, tags) {
                          ref
                              .read(fileListProvider.notifier)
                              .applyFilters(type, tags);
                          _updateRouteState(
                            selectedType: type,
                            selectedTags: tags,
                          );
                          _closeFilterDropdown();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_filterDropdownOverlay!);
  }

  void _closeFilterDropdown() {
    _filterDropdownOverlay?.remove();
    _filterDropdownOverlay = null;
  }

  void _openDetail(EngramFile file) {
    widget.onOpenDetail(file);
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(fileListProvider.select((s) => s.files));
    final loading = ref.watch(fileListProvider.select((s) => s.isLoading));
    final loadingMore = ref.watch(
      fileListProvider.select((s) => s.isLoadingMore),
    );
    final error = ref.watch(fileListProvider.select((s) => s.error));
    final searchQuery = ref.watch(
      fileListProvider.select((s) => s.searchQuery),
    );
    final activeType = ref.watch(
      fileListProvider.select((s) => s.selectedType),
    );
    final selectedTags = ref.watch(
      fileListProvider.select((s) => s.selectedTags),
    );
    final availableTags = ref.watch(
      fileListProvider.select((s) => s.availableTags),
    );
    final hasActiveFilters =
        selectedTags.isNotEmpty ||
        (activeType != null && activeType != 'all') ||
        searchQuery.isNotEmpty;
    final reliquary = ref.watch(reliquaryServiceProvider).valueOrNull;
    final isSearching = searchQuery.isNotEmpty;
    // Folders come from Engram, complete for this directory, rather than being
    // derived from however many pages of files happen to be loaded. Search
    // spans every folder, so the tree is meaningless while one is active: the
    // provider clears it, and this keeps the rule visible here too.
    final folders = isSearching
        ? const <FolderEntry>[]
        : ref.watch(fileListProvider.select((s) => s.folders));
    final visibleFiles = visibleFilesFor(
      files: files,
      currentPath: _folderPath.path,
      showFullPath:
          _groupingMode == GalleryGroupingMode.allFiles || isSearching,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: () => ref.read(fileListProvider.notifier).invalidate(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                        child: _buildHeader(context, files.length),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: _buildSearchBar(
                          context,
                          searchQuery,
                          files.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    SliverToBoxAdapter(
                      child: _buildFilterSection(
                        context,
                        activeType,
                        selectedTags,
                        availableTags,
                        hasActiveFilters: hasActiveFilters,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    _buildBody(
                      context,
                      folders,
                      visibleFiles,
                      loading,
                      loadingMore,
                      error,
                      hasActiveFilters: hasActiveFilters,
                      reliquary: reliquary,
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 32,
          bottom: 24,
          child: FloatingActionButton(
            onPressed: widget.onNavigateToUpload,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, int fileCount) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Knowledge Vault', style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          'Synchronizing your digital consciousness across $fileCount nodes.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    String searchQuery,
    int fileCount,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search your vault\u2026',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    ),
              filled: true,
              fillColor: cs.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _allFilesChip(context, fileCount),
      ],
    );
  }

  Widget _allFilesChip(BuildContext context, int fileCount) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grid_view, size: 16, color: cs.onPrimary),
          const SizedBox(width: 6),
          Text(
            'All Files ($fileCount)',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontFamily: 'Space Grotesk',
              fontSize: 14,
              letterSpacing: 0.05,
              color: cs.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(
    BuildContext context,
    String? activeType,
    Set<String> selectedTags,
    List<Map<String, dynamic>> availableTags, {
    required bool hasActiveFilters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(context, hasActiveFilters),
          if (_groupingMode == GalleryGroupingMode.folders) ...[
            const SizedBox(height: 12),
            _buildFolderCrumb(context),
          ],
          const SizedBox(height: 16),
          if (hasActiveFilters)
            _buildQuickFilters(
              context,
              activeType,
              selectedTags,
              availableTags,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, bool hasActiveFilters) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          key: _filterButtonKey,
          onTap: () => _openFilterDropdown(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border.all(
                color: hasActiveFilters ? cs.primary : cs.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list,
                  size: 18,
                  color: hasActiveFilters ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filter by Type',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontFamily: 'Space Grotesk',
                    fontSize: 14,
                    letterSpacing: 0.05,
                    color: hasActiveFilters ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: hasActiveFilters ? cs.primary : cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        _modeButton(
          context,
          tooltip: 'Grid view',
          icon: Icons.grid_view,
          selected: _viewMode == GalleryViewMode.grid,
          onTap: () => _setViewMode(GalleryViewMode.grid),
        ),
        _modeButton(
          context,
          tooltip: 'List view',
          icon: Icons.view_list,
          selected: _viewMode == GalleryViewMode.list,
          onTap: () => _setViewMode(GalleryViewMode.list),
        ),
        _modeButton(
          context,
          tooltip: 'Folder view',
          icon: Icons.account_tree_outlined,
          selected: _groupingMode == GalleryGroupingMode.folders,
          onTap: () => _setGroupingMode(GalleryGroupingMode.folders),
        ),
        _modeButton(
          context,
          tooltip: 'All files',
          icon: Icons.snippet_folder_outlined,
          selected: _groupingMode == GalleryGroupingMode.allFiles,
          onTap: () => _setGroupingMode(GalleryGroupingMode.allFiles),
        ),
      ],
    );
  }

  Widget _modeButton(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        isSelected: selected,
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        style: IconButton.styleFrom(
          backgroundColor: selected ? cs.primaryContainer : cs.surface,
          foregroundColor: selected
              ? cs.onPrimaryContainer
              : cs.onSurfaceVariant,
          side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildFolderCrumb(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: _folderPath.isRoot ? null : _goUpFolder,
          icon: const Icon(Icons.arrow_back, size: 18),
        ),
        const SizedBox(width: 4),
        Icon(Icons.folder_open, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _folderPath.isRoot ? 'Files' : _folderPath.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFilters(
    BuildContext context,
    String? activeType,
    Set<String> selectedTags,
    List<Map<String, dynamic>> availableTags,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            'Quick Filters:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'Space Mono',
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          for (final t in _fileTypes.where((ft) => ft.key != 'all')) ...[
            QuickFilterChip(
              icon: t.icon,
              label: t.label,
              isActive: activeType == t.key,
              onTap: () {
                final nextType = activeType == t.key ? null : t.key;
                ref.read(fileListProvider.notifier).setSelectedType(nextType);
                _updateRouteState(selectedType: nextType);
              },
            ),
            const SizedBox(width: 6),
          ],
          for (final tag in availableTags.where(
            (t) => selectedTags.contains(t['name']),
          )) ...[
            QuickFilterChip(
              icon: Icons.tag,
              label: tag['name'] as String,
              isActive: true,
              onTap: () => _toggleTag(tag['name'] as String),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<FolderEntry> folders,
    List<GalleryFileProjection> files,
    bool loading,
    bool loadingMore,
    String? error, {
    required bool hasActiveFilters,
    required ReliquaryService? reliquary,
  }) {
    if (loading) {
      return _buildLoadingGrid(context);
    }

    if (error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(error),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.read(fileListProvider.notifier).loadFiles(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (folders.isEmpty && files.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasActiveFilters ? Icons.search_off : Icons.cloud_upload,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                hasActiveFilters ? 'No matches' : 'No files yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                hasActiveFilters
                    ? 'Try adjusting your filters or search query'
                    : 'Tap + to upload',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (reliquary == null) {
      return _buildLoadingGrid(context);
    }

    if (_viewMode == GalleryViewMode.list) {
      return _buildListBody(context, folders, files, loadingMore);
    }

    return _buildGridBody(context, folders, files, reliquary, loadingMore);
  }

  Widget _buildGridBody(
    BuildContext context,
    List<FolderEntry> folders,
    List<GalleryFileProjection> files,
    ReliquaryService reliquary,
    bool loadingMore,
  ) {
    final itemCount = folders.length + files.length + (loadingMore ? 1 : 0);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= folders.length + files.length) {
            return const Center(child: CircularProgressIndicator());
          }
          if (index < folders.length) {
            final folder = folders[index];
            return FolderTile(
              key: ValueKey('folder:${folder.path}'),
              folder: folder,
              onTap: () => _openFolder(folder.path),
            );
          }
          final projection = files[index - folders.length];
          return FileTile(
            key: ValueKey(projection.file.id),
            file: projection.file,
            reliquary: reliquary,
            displayName: projection.displayName,
            locationLabel:
                _groupingMode == GalleryGroupingMode.allFiles ||
                    projection.directoryPath.isNotEmpty
                ? projection.directoryPath
                : null,
            onTap: () => _openDetail(projection.file),
          );
        }, childCount: itemCount),
      ),
    );
  }

  Widget _buildListBody(
    BuildContext context,
    List<FolderEntry> folders,
    List<GalleryFileProjection> files,
    bool loadingMore,
  ) {
    final itemCount = folders.length + files.length + (loadingMore ? 1 : 0);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= folders.length + files.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (index < folders.length) {
            final folder = folders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: FolderRow(
                folder: folder,
                onTap: () => _openFolder(folder.path),
              ),
            );
          }
          final projection = files[index - folders.length];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: FileRow(
              projection: projection,
              onTap: () => _openDetail(projection.file),
            ),
          );
        }, childCount: itemCount),
      ),
    );
  }

  Widget _buildLoadingGrid(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildLoadingTile(colors),
          childCount: 8,
        ),
      ),
    );
  }

  Widget _buildLoadingTile(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 112,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withAlpha(160),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                Icons.insert_drive_file_outlined,
                size: 32,
                color: colors.onSurfaceVariant.withAlpha(80),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _loadingBar(colors, widthFactor: 0.82),
          const SizedBox(height: 8),
          _loadingBar(colors, widthFactor: 0.52),
          const Spacer(),
          Row(
            children: [
              _loadingPill(colors),
              const SizedBox(width: 8),
              _loadingPill(colors, width: 56),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loadingBar(ColorScheme colors, {required double widthFactor}) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _loadingPill(ColorScheme colors, {double width = 72}) {
    return Container(
      width: width,
      height: 22,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withAlpha(180),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
