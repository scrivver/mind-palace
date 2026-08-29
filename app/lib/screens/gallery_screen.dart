import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/engram_file.dart';
import '../providers/file_list_provider.dart';
import '../providers/service_providers.dart';
import '../reliquary_service.dart';
import '../utils/breakpoints.dart';
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
    _syncSearchText(widget.initialSearchQuery);
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
      _syncSearchText(widget.initialSearchQuery);
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

  /// Pushes [value] into the search field without disturbing what the user is
  /// typing.
  ///
  /// Every debounced keystroke round-trips through the route (`?q=`) and comes
  /// back as [GalleryScreen.initialSearchQuery], so this runs mid-typing.
  /// Assigning `TextEditingController.text` there is what made the field
  /// highlight itself: that setter resets the selection to offset -1, and
  /// `EditableText` reacts to an invalid selection on a focused field by
  /// re-running its gained-focus behaviour — which on web and desktop is
  /// `selectAllOnFocus`, so the whole query ended up selected and the next
  /// character replaced it. Writing a [TextEditingValue] with an explicit
  /// collapsed caret never leaves the selection invalid, so that path is
  /// never taken.
  ///
  /// The route only ever carries the trimmed query, so comparing trimmed keeps
  /// a trailing space the user just typed from being clipped back out.
  void _syncSearchText(String value) {
    if (_searchCtrl.text.trim() == value.trim()) return;
    _searchCtrl.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
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

  /// The phone equivalent of [_openFilterDropdown]: the same panel, in a modal
  /// sheet rather than an overlay anchored to a button that is not there.
  Future<void> _openFilterSheet(BuildContext context) async {
    final state = ref.read(fileListProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: FilterDropdownPanel(
              fileTypes: _fileTypes,
              initialSelectedTags: state.selectedTags,
              initialTypeFilter: state.selectedType,
              availableTags: state.availableTags,
              onApply: (type, tags) {
                ref.read(fileListProvider.notifier).applyFilters(type, tags);
                _updateRouteState(selectedType: type, selectedTags: tags);
                Navigator.of(sheetContext).pop();
              },
            ),
          ),
        );
      },
    );
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

    final isMobile = isMobileWidth(context);
    final gutter = isMobile ? 16.0 : 32.0;

    final scrollView = RefreshIndicator(
      onRefresh: () => ref.read(fileListProvider.notifier).invalidate(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // The desktop page header becomes the mobile app bar's title,
              // leaving only the count line to sit above the search field.
              if (isMobile)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
                    child: _buildMobileSubtitle(context, files.length),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                    child: _buildHeader(context, files.length),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: _buildSearchBar(
                    context,
                    searchQuery,
                    files.length,
                    isMobile: isMobile,
                    hasActiveFilters: hasActiveFilters,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: isMobile ? 12 : 24)),
              SliverToBoxAdapter(
                child: _buildFilterSection(
                  context,
                  activeType,
                  selectedTags,
                  availableTags,
                  hasActiveFilters: hasActiveFilters,
                  isMobile: isMobile,
                  fileCount: files.length,
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: isMobile ? 16 : 32)),
              _buildBody(
                context,
                folders,
                visibleFiles,
                loading,
                loadingMore,
                error,
                hasActiveFilters: hasActiveFilters,
                reliquary: reliquary,
                isMobile: isMobile,
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );

    if (isMobile) {
      return Scaffold(
        appBar: _buildMobileAppBar(context),
        body: scrollView,
        floatingActionButton: FloatingActionButton(
          onPressed: widget.onNavigateToUpload,
          child: const Icon(Icons.add),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: scrollView),
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

  /// The four desktop toggle buttons collapse into two app bar actions: one
  /// that flips grid/list, one that flips folders/all files.
  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isGrid = _viewMode == GalleryViewMode.grid;
    final inFolders = _groupingMode == GalleryGroupingMode.folders;

    return AppBar(
      title: Text(
        'Knowledge Vault',
        style: theme.textTheme.headlineMedium?.copyWith(
          fontSize: 22,
          height: 28 / 22,
        ),
      ),
      actions: [
        IconButton(
          tooltip: isGrid ? 'Switch to list view' : 'Switch to grid view',
          icon: Icon(isGrid ? Icons.grid_view : Icons.view_list),
          onPressed: () => _setViewMode(
            isGrid ? GalleryViewMode.list : GalleryViewMode.grid,
          ),
        ),
        IconButton(
          tooltip: inFolders ? 'Show all files' : 'Browse folders',
          isSelected: inFolders,
          icon: const Icon(Icons.account_tree_outlined),
          selectedIcon: const Icon(Icons.account_tree),
          onPressed: () => _setGroupingMode(
            inFolders
                ? GalleryGroupingMode.allFiles
                : GalleryGroupingMode.folders,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMobileSubtitle(BuildContext context, int fileCount) {
    final theme = Theme.of(context);
    return Text(
      'Synchronizing $fileCount nodes.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
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
    int fileCount, {
    required bool isMobile,
    required bool hasActiveFilters,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          // Rebuilt from the controller so the clear button tracks the
          // keystroke. Reading `_searchCtrl.text` in build without listening
          // to it tied the button to whatever else rebuilt this widget, which
          // is the debounced provider update — so the button arrived 300ms
          // after the first character and lingered 300ms past the last.
          child: ListenableBuilder(
            listenable: _searchCtrl,
            builder: (context, _) => TextField(
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
        ),
        SizedBox(width: isMobile ? 8 : 12),
        // On a phone the count moves into the chip row and this slot carries
        // the filter sheet's entry point instead.
        if (isMobile)
          _mobileFilterButton(context, hasActiveFilters: hasActiveFilters)
        else
          _allFilesChip(context, fileCount),
      ],
    );
  }

  Widget _mobileFilterButton(
    BuildContext context, {
    required bool hasActiveFilters,
  }) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        tooltip: 'Filter',
        onPressed: () => _openFilterSheet(context),
        icon: const Icon(Icons.filter_list, size: 20),
        style: IconButton.styleFrom(
          foregroundColor: hasActiveFilters ? cs.primary : cs.onSurfaceVariant,
          side: BorderSide(
            color: hasActiveFilters ? cs.primary : cs.outlineVariant,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
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
    required bool isMobile,
    required int fileCount,
  }) {
    if (isMobile) {
      // The type dropdown and view toggles have moved to the filter sheet and
      // the app bar, so the chip row is the only always-on control left — and
      // it carries the file count the desktop chip used to show.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _buildQuickFilters(
              context,
              activeType,
              selectedTags,
              availableTags,
              isMobile: true,
              fileCount: fileCount,
            ),
          ),
          if (_groupingMode == GalleryGroupingMode.folders)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: _buildFolderCrumb(context),
            ),
        ],
      );
    }

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
              isMobile: false,
              fileCount: fileCount,
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
    List<Map<String, dynamic>> availableTags, {
    required bool isMobile,
    required int fileCount,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (isMobile) ...[
            QuickFilterChip(
              icon: Icons.grid_view,
              label: 'All Files ($fileCount)',
              isActive: activeType == null || activeType == 'all',
              onTap: () {
                ref.read(fileListProvider.notifier).setSelectedType(null);
                _updateRouteState(selectedType: null);
              },
            ),
            const SizedBox(width: 6),
          ] else ...[
            Text(
              'Quick Filters:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'Space Mono',
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
          ],
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
          // Matches the 16px gutter the rest of the mobile layout uses; the
          // row itself has to start flush so chips can scroll under the edge.
          if (isMobile) const SizedBox(width: 10),
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
    required bool isMobile,
  }) {
    final gutter = isMobile ? 16.0 : 32.0;

    if (loading) {
      return _buildLoadingGrid(context, isMobile: isMobile);
    }

    if (error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 48, gutter, 0),
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
          padding: EdgeInsets.fromLTRB(gutter, 48, gutter, 0),
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
      return _buildLoadingGrid(context, isMobile: isMobile);
    }

    if (_viewMode == GalleryViewMode.list) {
      return _buildListBody(
        context,
        folders,
        files,
        loadingMore,
        isMobile: isMobile,
      );
    }

    return _buildGridBody(
      context,
      folders,
      files,
      reliquary,
      loadingMore,
      isMobile: isMobile,
    );
  }

  /// Two columns at phone widths, sized by a measured extent rather than an
  /// aspect ratio: the text block under a tile's 16:9 thumbnail is a fixed
  /// stack of lines, so a ratio would shrink it along with the width and clip
  /// it on a narrow phone or at a large text scale.
  SliverGridDelegate _tileGridDelegate(
    BuildContext context, {
    required bool isMobile,
    required double aspectRatio,
  }) {
    if (!isMobile) {
      return SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      );
    }

    const spacing = 12.0;
    const gutter = 16.0;
    final tileWidth =
        (MediaQuery.sizeOf(context).width - gutter * 2 - spacing) / 2;
    // 44 of fixed padding and gaps, plus the name, location and badge lines.
    final textBlock = 44 + MediaQuery.textScalerOf(context).scale(56);

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      mainAxisExtent: tileWidth * 9 / 16 + textBlock,
    );
  }

  Widget _buildGridBody(
    BuildContext context,
    List<FolderEntry> folders,
    List<GalleryFileProjection> files,
    ReliquaryService reliquary,
    bool loadingMore, {
    required bool isMobile,
  }) {
    final itemCount = folders.length + files.length + (loadingMore ? 1 : 0);
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
      sliver: SliverGrid(
        gridDelegate: _tileGridDelegate(
          context,
          isMobile: isMobile,
          aspectRatio: 1.1,
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
              compact: isMobile,
            );
          }
          final projection = files[index - folders.length];
          return FileTile(
            key: ValueKey(projection.file.id),
            file: projection.file,
            reliquary: reliquary,
            compact: isMobile,
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
    bool loadingMore, {
    required bool isMobile,
  }) {
    final itemCount = folders.length + files.length + (loadingMore ? 1 : 0);
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
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
                compact: isMobile,
              ),
            );
          }
          final projection = files[index - folders.length];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: FileRow(
              projection: projection,
              onTap: () => _openDetail(projection.file),
              compact: isMobile,
            ),
          );
        }, childCount: itemCount),
      ),
    );
  }

  Widget _buildLoadingGrid(BuildContext context, {required bool isMobile}) {
    final colors = Theme.of(context).colorScheme;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
      sliver: SliverGrid(
        gridDelegate: _tileGridDelegate(
          context,
          isMobile: isMobile,
          aspectRatio: 0.9,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildLoadingTile(colors, isMobile: isMobile),
          childCount: isMobile ? 6 : 8,
        ),
      ),
    );
  }

  Widget _buildLoadingTile(ColorScheme colors, {required bool isMobile}) {
    if (isMobile) return _buildCompactLoadingTile(colors);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: isMobile ? 88 : 112,
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

  /// Mirrors the compact [FileTile]: a 16:9 thumbnail flush to the top edge
  /// and a padded text block under it, so the skeleton occupies the same cell
  /// as the tile that replaces it.
  Widget _buildCompactLoadingTile(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: colors.surfaceContainerHighest.withAlpha(160),
              child: Center(
                child: Icon(
                  Icons.insert_drive_file_outlined,
                  size: 28,
                  color: colors.onSurfaceVariant.withAlpha(80),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _loadingBar(colors, widthFactor: 0.82),
                const SizedBox(height: 8),
                _loadingBar(colors, widthFactor: 0.52),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _loadingPillBox(colors)),
                    const SizedBox(width: 8),
                    Expanded(child: _loadingPillBox(colors)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingPillBox(ColorScheme colors) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withAlpha(180),
        borderRadius: BorderRadius.circular(999),
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
