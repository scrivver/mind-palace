import 'dart:async';

import 'package:flutter/material.dart';

import '../engram_service.dart';
import '../models/engram_file.dart';
import '../reliquary_service.dart';
import 'file_detail_screen.dart';
import 'upload_screen.dart';

class GalleryScreen extends StatefulWidget {
  final EngramService engram;
  final ReliquaryService reliquary;
  final VoidCallback onLogout;
  final String username;

  const GalleryScreen({
    super.key,
    required this.engram,
    required this.reliquary,
    required this.onLogout,
    required this.username,
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

  List<Map<String, dynamic>> _availableTags = [];
  final Set<String> _selectedTags = {};

  String? _fileType;
  DateTimeRange? _dateRange;
  String _sort = 'created_desc';

  static const _pageSize = 50;
  static const _fileTypes = <({String key, String label, IconData icon})>[
    (key: 'all', label: 'All Files', icon: Icons.folder_copy),
    (key: 'pdf', label: 'PDF', icon: Icons.picture_as_pdf),
    (key: 'image', label: 'Images', icon: Icons.image),
    (key: 'text', label: 'Notes', icon: Icons.description),
    (key: 'code', label: 'Code', icon: Icons.terminal),
  ];
  static const _sortOptions = <({String key, String label})>[
    (key: 'created_desc', label: 'Newest first'),
    (key: 'mtime_desc', label: 'Recently modified'),
    (key: 'size_desc', label: 'Largest first'),
    (key: 'size_asc', label: 'Smallest first'),
  ];

  String? _activeTypeFilter;

  bool get _hasActiveFilters =>
      _selectedTags.isNotEmpty ||
      (_activeTypeFilter != null && _activeTypeFilter != 'all') ||
      _dateRange != null ||
      _sort != 'created_desc' ||
      _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _loadTags();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
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

  void _toggleTag(String name) {
    setState(() {
      if (!_selectedTags.remove(name)) _selectedTags.add(name);
    });
    _loadFiles();
  }

  void _onTypeFilterChanged(String? key) {
    setState(() => _activeTypeFilter = key);
    _loadFiles();
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _FilterSheet(
        fileTypes: _fileTypes,
        sortOptions: _sortOptions,
        initialFileType: _fileType,
        initialDateRange: _dateRange,
        initialSort: _sort,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _fileType = result.fileType;
      _dateRange = result.dateRange;
      _sort = result.sort;
    });
    _loadFiles();
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
    return Column(
      children: [
        _buildHeader(context),
        _buildSearchBar(context),
        _buildTypeFilters(context),
        if (_availableTags.isNotEmpty) _buildTagBar(),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Knowledge Vault', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Synchronizing your digital consciousness across ${_files.length} nodes.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search filenames\u2026',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildTypeFilters(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: _fileTypes.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == _fileTypes.length) {
            return IconButton(
              icon: Badge(
                isLabelVisible: _hasActiveFilters,
                smallSize: 6,
                child: const Icon(Icons.tune, size: 18),
              ),
              tooltip: 'More filters',
              onPressed: _openFilterSheet,
              visualDensity: VisualDensity.compact,
            );
          }
          final t = _fileTypes[i];
          final selected = _activeTypeFilter == t.key ||
              (_activeTypeFilter == null && t.key == 'all');
          return FilterChip(
            avatar: Icon(t.icon, size: 16),
            label: Text(t.label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => _onTypeFilterChanged(t.key == 'all' ? null : t.key),
          );
        },
      ),
    );
  }

  Widget _buildTagBar() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: _availableTags.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final tag = _availableTags[i];
          final name = tag['name'] as String;
          final count = (tag['file_count'] as num?)?.toInt() ?? 0;
          final selected = _selectedTags.contains(name);
          return FilterChip(
            label: Text(count > 0 ? '$name ($count)' : name),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => _toggleTag(name),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadFiles, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_upload,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No files yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + to upload',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.extentAfter < 200) {
            _loadMore();
          }
          return false;
        },
        child: Stack(
          children: [
            GridView.builder(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
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
            Positioned(
              right: 24,
              bottom: 24,
              child: FloatingActionButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UploadScreen(
                        reliquary: widget.reliquary,
                        onLogout: widget.onLogout,
                        username: widget.username,
                      ),
                    ),
                  );
                  _refreshAll();
                },
                child: const Icon(Icons.add),
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
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.file.filename,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _typeBadge(context, widget.file.mimeType ?? ''),
                      const SizedBox(width: 8),
                      Text(
                        widget.file.formattedSize,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _relativeTime(widget.file.mtime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'Inter',
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'Space Mono',
          fontSize: 9,
          height: 1.3,
          color: theme.colorScheme.onSurfaceVariant,
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

class _FilterResult {
  final String? fileType;
  final DateTimeRange? dateRange;
  final String sort;
  const _FilterResult(this.fileType, this.dateRange, this.sort);
}

class _FilterSheet extends StatefulWidget {
  final List<({String key, String label, IconData icon})> fileTypes;
  final List<({String key, String label})> sortOptions;
  final String? initialFileType;
  final DateTimeRange? initialDateRange;
  final String initialSort;

  const _FilterSheet({
    required this.fileTypes,
    required this.sortOptions,
    required this.initialFileType,
    required this.initialDateRange,
    required this.initialSort,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _fileType;
  DateTimeRange? _dateRange;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _fileType = widget.initialFileType;
    _dateRange = widget.initialDateRange;
    _sort = widget.initialSort;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  String _formatRange(DateTimeRange r) {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '${fmt(r.start)} \u2192 ${fmt(r.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Type', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.fileTypes.map((t) {
                final selected = _fileType == t.key;
                return FilterChip(
                  avatar: Icon(t.icon, size: 18),
                  label: Text(t.label),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) =>
                      setState(() => _fileType = selected ? null : t.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Date modified', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      _dateRange == null
                          ? 'Any date'
                          : _formatRange(_dateRange!),
                    ),
                    onPressed: _pickDateRange,
                  ),
                ),
                if (_dateRange != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Clear date range',
                    onPressed: () => setState(() => _dateRange = null),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Sort by', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _sort,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: widget.sortOptions
                  .map(
                    (o) => DropdownMenuItem(value: o.key, child: Text(o.label)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _sort = v);
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _FilterResult(_fileType, _dateRange, _sort),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
