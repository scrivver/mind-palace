import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/engram_file.dart';
import '../providers/file_list_provider.dart';
import '../providers/service_providers.dart';
import '../reliquary_service.dart';
import '../widgets/gallery/file_tile.dart';
import '../widgets/gallery/filter_dropdown_panel.dart';
import '../widgets/gallery/quick_filter_chip.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToUpload;
  final void Function(EngramFile file) onOpenDetail;
  final int refreshTrigger;

  const GalleryScreen({
    super.key,
    this.onNavigateToUpload,
    required this.onOpenDetail,
    required this.refreshTrigger,
  });

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  final ScrollController _scrollCtrl = ScrollController();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(fileListProvider.notifier).loadFiles();
      ref.read(fileListProvider.notifier).loadTags();
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(GalleryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      ref.read(fileListProvider.notifier).invalidate();
    }
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
      ref.read(fileListProvider.notifier).setSearchQuery(value.trim());
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(fileListProvider.notifier).loadMore();
    }
  }

  void _toggleTag(String name) {
    ref.read(fileListProvider.notifier).toggleTag(name);
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
    final error = ref.watch(fileListProvider.select((s) => s.error));
    final hasMore = ref.watch(fileListProvider.select((s) => s.hasMore));
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
                      files,
                      loading,
                      error,
                      hasMore,
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

    return Row(
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
                ref
                    .read(fileListProvider.notifier)
                    .setSelectedType(activeType == t.key ? null : t.key);
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
    List<EngramFile> files,
    bool loading,
    String? error,
    bool hasMore, {
    required bool hasActiveFilters,
    required ReliquaryService? reliquary,
  }) {
    if (loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(32, 48, 32, 0),
          child: CircularProgressIndicator(),
        ),
      );
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

    if (files.isEmpty) {
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
          if (index >= files.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final file = files[index];
          return FileTile(
            key: ValueKey(file.id),
            file: file,
            reliquary: reliquary!,
            onTap: () => _openDetail(file),
          );
        }, childCount: files.length + (hasMore ? 1 : 0)),
      ),
    );
  }
}
