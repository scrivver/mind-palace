import 'dart:async';

import 'package:flutter/material.dart';

import '../engram_service.dart';
import '../models/engram_file.dart';
import '../reliquary_service.dart';
import 'file_detail_screen.dart';


class GalleryScreen extends StatefulWidget {
  final EngramService engram;
  final ReliquaryService reliquary;
  final VoidCallback onLogout;
  final String username;
  final VoidCallback? onNavigateToUpload;

  const GalleryScreen({
    super.key,
    required this.engram,
    required this.reliquary,
    required this.onLogout,
    required this.username,
    this.onNavigateToUpload,
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
                      child: _FilterDropdownPanel(
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

  Future<void> _openDetail(EngramFile file) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FileDetailScreen(
          initial: file,
          engram: widget.engram,
          reliquary: widget.reliquary,
          onLogout: widget.onLogout,
          username: widget.username,
        ),
      ),
    );
    if (deleted == true) {
      _refreshAll();
    }
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
            _QuickFilterChip(
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
            _QuickFilterChip(
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
            return _FileTile(
              file: file,
              reliquary: widget.reliquary,
              onTap: () => _openDetail(file),
            );
          },
        ),
      );
  }
}

class _QuickFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final fg = isActive ? cs.primary : cs.onSurfaceVariant;
    final bg = isActive ? cs.primaryContainer : cs.surfaceContainerLow;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
              color: isActive ? cs.primary : cs.outlineVariant.withAlpha(76)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'Space Grotesk',
                fontSize: 11,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends StatefulWidget {
  final EngramFile file;
  final ReliquaryService reliquary;
  final VoidCallback onTap;

  const _FileTile({
    required this.file,
    required this.reliquary,
    required this.onTap,
  });

  @override
  State<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<_FileTile> {
  String? _thumbUrl;

  @override
  void initState() {
    super.initState();
    if (_supportsThumbnail(widget.file.mimeType ?? '')) {
      _loadThumbnail();
    }
  }

  String? _thumbKeyFor(String filePath) {
    const prefix = 'files/';
    if (!filePath.startsWith(prefix)) return null;
    return 'thumbs/${filePath.substring(prefix.length)}';
  }

  bool _supportsThumbnail(String mime) =>
      mime.startsWith('image/') ||
      mime.startsWith('video/') ||
      mime == 'application/pdf';

  Future<void> _loadThumbnail() async {
    final key = _thumbKeyFor(widget.file.filePath);
    if (key == null) return;
    try {
      final url = await widget.reliquary.presignDownload(key);
      if (mounted) setState(() => _thumbUrl = url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
                child: Container(
                  color: theme.colorScheme.surfaceContainer,
                  child: _thumbUrl != null
                      ? Image.network(
                          _thumbUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, _, _) => _fileIcon(context),
                        )
                      : _fileIcon(context),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.file.filename,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _typeBadge(context, widget.file.mimeType ?? ''),
                      const SizedBox(width: 6),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.file.formattedSize,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'Space Mono',
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _relativeTime(widget.file.mtime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'Inter',
                          fontStyle: FontStyle.italic,
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileIcon(BuildContext context) {
    return Center(
      child: Icon(
        _iconForMime(widget.file.mimeType ?? ''),
        size: 36,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _typeBadge(BuildContext context, String mime) {
    final theme = Theme.of(context);
    final label = _shortType(mime);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'Space Mono',
          fontSize: 10,
          height: 1.3,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  String _shortType(String mime) {
    if (mime.contains('pdf')) return 'PDF';
    if (mime.startsWith('image/')) return 'IMG';
    if (mime.startsWith('video/')) return 'VID';
    if (mime.startsWith('audio/')) return 'AUD';
    if (mime.contains('zip') || mime.contains('tar') || mime.contains('rar')) {
      return 'ARC';
    }
    if (mime.contains('text') || mime.contains('markdown') || mime.contains('md')) {
      return 'TXT';
    }
    if (mime.contains('javascript') || mime.contains('python') ||
        mime.contains('json') || mime.contains('html') || mime.contains('xml')) {
      return 'CODE';
    }
    return 'FILE';
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  IconData _iconForMime(String mime) {
    if (mime.startsWith('image/')) return Icons.image;
    if (mime.startsWith('video/')) return Icons.videocam;
    if (mime.startsWith('audio/')) return Icons.audiotrack;
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    if (mime.contains('zip') || mime.contains('archive')) {
      return Icons.archive;
    }
    return Icons.insert_drive_file;
  }
}

class _FilterDropdownPanel extends StatefulWidget {
  final List<({String key, String label, IconData icon})> fileTypes;
  final TextEditingController searchCtrl;
  final Set<String> draftSelectedTags;
  final String? draftTypeFilter;
  final List<Map<String, dynamic>> availableTags;
  final void Function(String key) onToggleType;
  final void Function(String name) onToggleTag;
  final VoidCallback onClearAll;
  final VoidCallback onApply;

  const _FilterDropdownPanel({
    required this.fileTypes,
    required this.searchCtrl,
    required this.draftSelectedTags,
    required this.draftTypeFilter,
    required this.availableTags,
    required this.onToggleType,
    required this.onToggleTag,
    required this.onClearAll,
    required this.onApply,
  });

  @override
  State<_FilterDropdownPanel> createState() => _FilterDropdownPanelState();
}

class _FilterDropdownPanelState extends State<_FilterDropdownPanel> {
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    widget.searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.searchCtrl.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchText = widget.searchCtrl.text.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final typeItems =
        widget.fileTypes.where((t) => t.key != 'all').map((t) {
      final checked = widget.draftTypeFilter == t.key;
      final match =
          _searchText.isEmpty || t.label.toLowerCase().contains(_searchText);
      return (key: t.key, label: t.label, icon: t.icon, checked: checked, match: match);
    }).toList();

    final tagItems = widget.availableTags.map((t) {
      final name = t['name'] as String;
      final count = (t['file_count'] as num?)?.toInt() ?? 0;
      final checked = widget.draftSelectedTags.contains(name);
      final match =
          _searchText.isEmpty || name.toLowerCase().contains(_searchText);
      return (label: name, count: count, checked: checked, match: match);
    }).toList();

    final allItems = [
      ...typeItems
          .where((i) => i.match)
          .map((i) => _buildItemRow(
              context, i.label, i.icon, i.checked, () => widget.onToggleType(i.key))),
      ...tagItems
          .where((i) => i.match)
          .map((i) => _buildItemRow(context, i.label, Icons.tag, i.checked,
              () => widget.onToggleTag(i.label))),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: widget.searchCtrl,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search tags\u2026',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 32, minHeight: 0),
                prefixIcon: Icon(Icons.search,
                    size: 16, color: cs.onSurfaceVariant),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView(
            shrinkWrap: true,
            children: allItems,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: cs.outlineVariant.withAlpha(76))),
            color: cs.surfaceContainerLow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              TextButton(
                onPressed: widget.onClearAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600),
                ),
                child: Text('Clear All',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ),
              const Spacer(),
              FilledButton(
                onPressed: widget.onApply,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(BuildContext context, String label, IconData icon,
      bool checked, VoidCallback onTap) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: checked,
                onChanged: (_) => onTap(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: cs.outlineVariant),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
