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

  String? _fileType; // null | image | video | audio | pdf | other
  DateTimeRange? _dateRange;
  String _sort = 'created_desc';

  static const _pageSize = 50;
  static const _fileTypes = <({String key, String label, IconData icon})>[
    (key: 'image', label: 'Image', icon: Icons.image),
    (key: 'video', label: 'Video', icon: Icons.videocam),
    (key: 'audio', label: 'Audio', icon: Icons.audiotrack),
    (key: 'pdf', label: 'PDF', icon: Icons.picture_as_pdf),
    (key: 'other', label: 'Other', icon: Icons.insert_drive_file),
  ];
  static const _sortOptions = <({String key, String label})>[
    (key: 'created_desc', label: 'Newest first'),
    (key: 'mtime_desc', label: 'Recently modified'),
    (key: 'size_desc', label: 'Largest first'),
    (key: 'size_asc', label: 'Smallest first'),
  ];

  bool get _hasActiveFilters =>
      _selectedTags.isNotEmpty ||
      _fileType != null ||
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
        // Drop any selected tags that no longer exist.
        final names = tags.map((t) => t['name'] as String).toSet();
        _selectedTags.retainWhere(names.contains);
      });
    } catch (_) {
      // Tag chips are optional; silently ignore failures.
    }
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
      final files = await widget.engram.listFiles(
        offset: 0,
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

  void _clearFilters() {
    setState(() {
      _selectedTags.clear();
      _fileType = null;
      _dateRange = null;
      _sort = 'created_desc';
      _searchQuery = '';
      _searchCtrl.clear();
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
        ),
      ),
    );
    if (deleted == true) {
      _refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Files'),
            if (_files.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '(${_files.length})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              smallSize: 8,
              child: const Icon(Icons.tune),
            ),
            tooltip: 'Filters',
            onPressed: _openFilterSheet,
          ),
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear filters',
              onPressed: _clearFilters,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(widget.username),
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: widget.onLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_availableTags.isNotEmpty) _buildTagBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => UploadScreen(reliquary: widget.reliquary),
          ));
          _refreshAll();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search filenames…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildTagBar() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            onSelected: (_) => _toggleTag(name),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
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
            Icon(Icons.cloud_upload,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No files yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Tap + to upload',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
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
        child: GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
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

  // Reliquary stores thumbs at thumbs/<user>/... mirroring files/<user>/...
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
    } catch (_) {
      // Thumbnail may not exist yet (async generation) — fall through to icon.
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _thumbUrl != null
              ? Image.network(
                  _thumbUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _placeholder(context),
                )
              : _placeholder(context),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconForMime(widget.file.mimeType ?? ''),
            size: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.file.filename,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
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
    return '${fmt(r.start)} → ${fmt(r.end)}';
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
                  onSelected: (_) => setState(
                      () => _fileType = selected ? null : t.key),
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
                    icon: const Icon(Icons.date_range),
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
                    icon: const Icon(Icons.clear),
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
                  .map((o) => DropdownMenuItem(
                        value: o.key,
                        child: Text(o.label),
                      ))
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
