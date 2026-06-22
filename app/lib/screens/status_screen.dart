import 'package:flutter/material.dart';

import '../reliquary_service.dart';

class StatusScreen extends StatefulWidget {
  final ReliquaryService reliquary;

  const StatusScreen({
    super.key,
    required this.reliquary,
  });

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  Map<String, dynamic>? _reliquaryStats;
  bool _loadingReliquary = true;
  String? _reliquaryError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingReliquary = true;
      _reliquaryError = null;
    });

    await _loadReliquaryStats();
  }

  Future<void> _loadReliquaryStats() async {
    try {
      final stats = await widget.reliquary.getStats();
      if (mounted) {
        setState(() {
          _reliquaryStats = stats;
          _loadingReliquary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reliquaryError = e.toString();
          _loadingReliquary = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildStorageCapacity(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sanctuary Health',
            style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          'Overview of your personal digital sanctuary',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildStorageCapacity() {
    if (_loadingReliquary) {
      return _buildCard(
        child: const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_reliquaryError != null || _reliquaryStats == null) {
      return _buildCard(
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Storage data unavailable',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      );
    }

    final stats = _reliquaryStats!;
    final byType = stats['by_type'] as Map<String, dynamic>? ?? {};
    final fileCount = (stats['file_count'] as num?)?.toInt() ?? 0;
    final totalSize = (stats['total_size'] as num?)?.toInt() ?? 0;
    const displayCapacity = 100 * 1024 * 1024 * 1024; // 100 GB

    final categories = _buildStorageCategories(byType);
    final usedBytes = totalSize;
    final capacityFraction =
        usedBytes > 0 ? (usedBytes / displayCapacity).clamp(0.0, 1.0) : 0.0;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('Storage Capacity',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: capacityFraction,
              minHeight: 8,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatBytes(usedBytes)} / ${_formatBytes(displayCapacity)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text('Total files: $fileCount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
          const SizedBox(height: 12),
          ...categories.map(
              (c) => _buildCategoryRow(c.$1, c.$2, c.$3)),
        ],
      ),
    );
  }

  List<(String, IconData, int)> _buildStorageCategories(
      Map<String, dynamic> byType) {
    final image = (byType['image'] as num?)?.toInt() ?? 0;
    final video = (byType['video'] as num?)?.toInt() ?? 0;
    final audio = (byType['audio'] as num?)?.toInt() ?? 0;
    final application = (byType['application'] as num?)?.toInt() ?? 0;
    final text = (byType['text'] as num?)?.toInt() ?? 0;
    final otherKeys = byType.keys
        .where((k) => !['image', 'video', 'audio', 'application', 'text']
            .contains(k))
        .fold<int>(0, (sum, k) => sum + ((byType[k] as num?)?.toInt() ?? 0));

    return [
      ('Documents', Icons.description, application),
      ('Media', Icons.perm_media, image + video + audio),
      ('Research', Icons.auto_stories, text),
      ('Snippets', Icons.note, otherKeys),
    ];
  }

  Widget _buildCategoryRow(
      String label, IconData icon, int fileCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text('$fileCount files',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}
