import 'dart:async';

import 'package:flutter/material.dart';

import '../engram_service.dart';
import '../models/engram_file.dart';
import '../reliquary_service.dart';
import '../widgets/gallery/file_tile.dart';
import '../widgets/gallery/filter_dropdown_panel.dart';
import '../widgets/gallery/quick_filter_chip.dart';


class GalleryScreen extends StatefulWidget {
  final EngramService engram;
  final ReliquaryService reliquary;
  final VoidCallback onLogout;
  final String username;
  final VoidCallback? onNavigateToUpload;
  final void Function(EngramFile file) onOpenDetail;
  final int refreshTrigger;

  const GalleryScreen({
    super.key,
    required this.engram,
    required this.reliquary,
    required this.onLogout,
    required this.username,
    this.onNavigateToUpload,
    required this.onOpenDetail,
    required this.refreshTrigger,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final List<EngramFile> _files = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  final ScrollController _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _availableTags = [];
  final Set<String> _selectedTags = {};

  String? _fileType;
  DateTimeRange? _dateRange;
  final String _sort = 'created_desc';

  static const _pageSize = 50;
  static const _fileTypes = <({String key, String label, IconData icon})>[
    (key: 'all', label: 'All Files', icon: Icons.grid_view),
    (key: 'image', label: 'Images', icon: Icons.image),
    (key: 'video', label: 'Video', icon: Icons.videocam),
    (key: 'audio', label: 'Audio', icon: Icons.audiotrack),
    (key: 'pdf', label: 'PDF', icon: Icons.picture_as_pdf),
    (key: 'other', label: 'Other', icon: Icons.insert_drive_file),
  ];


  String? _activeTypeFilter;

  final GlobalKey _filterButtonKey = GlobalKey();
  final TextEditingController _filterSearchCtrl = TextEditingController();
  OverlayEntry? _filterDropdownOverlay;
  Set<String> _draftSelectedTags = {};
  String? _draftTypeFilter;

  bool get _hasActiveFilters =>
      _selectedTags.isNotEmpty ||
      (_activeTypeFilter != null && _activeTypeFilter != 'all') ||
      _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _loadTags();
    _scrollCtrl.addListener(_onScroll);
  }

  void _initDraftState() {
    _draftSelectedTags = Set.from(_selectedTags);
    _draftTypeFilter = _activeTypeFilter;
    _filterSearchCtrl.clear();
  }

  @override
  void didUpdateWidget(GalleryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _refreshAll();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _filterSearchCtrl.dispose();
    _scrollCtrl.dispose();
    _closeFilterDropdown();
    super.dispose();
  }

  Future<void> _loadTags() async {
    try {
      final tags = await widget.engram.listTags();
      if (!mounted) return;
      setState(() {
        _availableTags = tags;
        final names = tags.map((t) => t['name'] as String).toSet();
        _selectedTags.retainWhere(names.contains);
      });
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadFiles(), _loadTags()]);
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final fileType =
          (_activeTypeFilter != null && _activeTypeFilter != 'all')
              ? _activeTypeFilter
              : _fileType;
      final files = await widget.engram.listFiles(
        offset: 0,
        limit: _pageSize,
        query: _searchQuery,
        tags: _selectedTags.toList(),
        fileType: fileType,
        from: _dateRange?.start,
        to: _dateRange?.end,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _files
          ..clear()
          ..addAll(files);
        _hasMore = files.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load files';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final files = await widget.engram.listFiles(
        offset: _files.length,
        limit: _pageSize,
        query: _searchQuery,
        tags: _selectedTags.toList(),
        fileType: _fileType,
        from: _dateRange?.start,
        to: _dateRange?.end,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _files.addAll(files);
        _hasMore = files.length == _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
      _loadFiles();
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _toggleTag(String name) {
    if (!_selectedTags.remove(name)) _selectedTags.add(name);
    _loadFiles();
  }

  void _openFilterDropdown(BuildContext context) {
    _initDraftState();
    final renderBox =
        _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    const dropdownWidth = 288.0;

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
                    surfaceTintColor:
                        Theme.of(context).colorScheme.surfaceTint,
                    child: SizedBox(
                      width: dropdownWidth,
                      child: FilterDropdownPanel(
                        fileTypes: _fileTypes,
                        searchCtrl: _filterSearchCtrl,
                        draftSelectedTags: _draftSelectedTags,
                        draftTypeFilter: _draftTypeFilter,
                        availableTags: _availableTags,
                        onToggleType: (key) {
                          setState(() => _draftTypeFilter =
                              _draftTypeFilter == key ? null : key);
                          _filterDropdownOverlay?.markNeedsBuild();
                        },
                        onToggleTag: (name) {
                          setState(() {
                            if (!_draftSelectedTags.remove(name)) {
                              _draftSelectedTags.add(name);
                            }
                          });
                          _filterDropdownOverlay?.markNeedsBuild();
                        },
                        onClearAll: () {
                          setState(() {
                            _draftSelectedTags.clear();
                            _draftTypeFilter = null;
                          });
                          _filterDropdownOverlay?.markNeedsBuild();
                        },
                        onApply: () {
                          _activeTypeFilter = _draftTypeFilter;
                          _selectedTags
                            ..clear()
                            ..addAll(_draftSelectedTags);
                          _closeFilterDropdown();
                          _loadFiles();
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: _refreshAll,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                      child: _buildHeader(context),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: _buildSearchBar(context),
                    ),
                    const SizedBox(height: 24),
                    _buildFilterSection(context),
                    const SizedBox(height: 32),
                    _buildBody(context),
                    const SizedBox(height: 24),
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

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Knowledge Vault',
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Synchronizing your digital consciousness across ${_files.length} nodes.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
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
              prefixIcon:
                  Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.clear, size: 18,
                          color: cs.onSurfaceVariant),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    ),
              filled: true,
              fillColor: cs.surfaceContainerLow,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                borderSide:
                    BorderSide(color: cs.primary, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _allFilesChip(context),
      ],
    );
  }

  Widget _allFilesChip(BuildContext context) {
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
            'All Files (${_files.length})',
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

  Widget _buildFilterSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(context),
          const SizedBox(height: 16),
          _buildQuickFilters(context),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasFilters = _hasActiveFilters;

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
                  color: hasFilters ? cs.primary : cs.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list,
                    size: 18,
                    color: hasFilters ? cs.primary : cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Filter by Type',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontFamily: 'Space Grotesk',
                    fontSize: 14,
                    letterSpacing: 0.05,
                    color: hasFilters ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.keyboard_arrow_down,
                    size: 18,
                    color: hasFilters ? cs.primary : cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFilters(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final activeType = _activeTypeFilter;

    if (!_hasActiveFilters) return const SizedBox.shrink();

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
                _activeTypeFilter =
                    _activeTypeFilter == t.key ? null : t.key;
                _loadFiles();
              },
            ),
            const SizedBox(width: 6),
          ],
          for (final tag in _availableTags
              .where((t) => _selectedTags.contains(t['name']))) ...[
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

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(32, 48, 32, 0),
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadFiles, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      final hasFilters = _hasActiveFilters || _searchCtrl.text.isNotEmpty;
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.cloud_upload,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters ? 'No matches' : 'No files yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              hasFilters
                  ? 'Try adjusting your filters or search query'
                  : 'Tap + to upload',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: _files.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _files.length) {
              return const Center(child: CircularProgressIndicator());
            }
            final file = _files[index];
            return FileTile(
              file: file,
              reliquary: widget.reliquary,
              onTap: () => _openDetail(file),
            );
          },
        ),
      );
  }
}
