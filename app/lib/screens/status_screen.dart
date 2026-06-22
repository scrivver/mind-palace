import 'package:flutter/material.dart';

import '../engram_service.dart';
import '../reliquary_service.dart';

class StatusScreen extends StatefulWidget {
  final EngramService engram;
  final ReliquaryService reliquary;

  const StatusScreen({
    super.key,
    required this.engram,
    required this.reliquary,
  });

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  Map<String, dynamic>? _engramStats;
  Map<String, dynamic>? _reliquaryStats;
  Map<String, dynamic>? _activity;
  bool _loadingEngram = true;
  bool _loadingReliquary = true;
  bool _loadingActivity = true;
  String? _engramError;
  String? _reliquaryError;
  String? _activityError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingEngram = true;
      _loadingReliquary = true;
      _engramError = null;
      _reliquaryError = null;
    });

    await Future.wait([
      _loadEngramStats(),
      _loadReliquaryStats(),
      _loadActivity(),
    ]);
  }

  Future<void> _loadEngramStats() async {
    try {
      final stats = await widget.engram.getStats();
      if (mounted) {
        setState(() {
          _engramStats = stats;
          _loadingEngram = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _engramError = e.toString();
          _loadingEngram = false;
        });
      }
    }
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

  Future<void> _loadActivity() async {
    try {
      final result = await widget.engram.getActivity(limit: 20);
      if (mounted) {
        setState(() {
          _activity = result;
          _loadingActivity = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activityError = e.toString();
          _loadingActivity = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildEngramEngineCard(),
            const SizedBox(height: 24),
            _buildMetricTiles(),
            const SizedBox(height: 24),
            _buildStorageCapacity(),
            const SizedBox(height: 32),
            _buildRecentActivity(),
          ],
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
          'Real-time optimization metrics for your personal digital sanctuary',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildEngramEngineCard() {
    if (_loadingEngram) {
      return _buildCard(
        child: const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_engramError != null || _engramStats == null) {
      return _buildCard(
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Engine data unavailable',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      );
    }

    final stats = _engramStats!;
    final status = stats['status'] as String? ?? 'healthy';
    final efficiency = stats['efficiency_pct'] as int? ?? 100;
    final activeProcess = stats['active_process'] as String? ?? '';
    final syncFrequency = stats['sync_frequency'] as String? ?? '';
    final totalFiles = stats['total_files'] as int? ?? 0;
    final filesByStatus = stats['files_by_status'] as Map<String, dynamic>? ?? {};

    final isDegraded = status == 'degraded' || status == 'error';
    final statusColor = isDegraded
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory, color: statusColor),
              const SizedBox(width: 8),
              Text('Engram Engine',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDegraded
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatColumn('Efficiency', '$efficiency%'),
              const SizedBox(width: 32),
              _buildStatColumn('Active Process', activeProcess),
              const SizedBox(width: 32),
              _buildStatColumn('Sync Frequency', syncFrequency),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatColumn('Total Files', '$totalFiles'),
              const SizedBox(width: 32),
              if (filesByStatus.isNotEmpty)
                _buildStatColumn(
                    'Failed', '${filesByStatus['failed'] ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                )),
      ],
    );
  }

  Widget _buildMetricTiles() {
    final latency = _engramStats?['latency_ms'] as int? ?? 42;
    final syncSpeed = _engramStats?['sync_speed_mbps'] as num? ?? 12.5;
    final uptime = _engramStats?['uptime_pct'] as num? ?? 99.9;

    return Row(
      children: [
        Expanded(
            child: _buildMetricTile(
                'System Latency', '$latency ms', Icons.timer_outlined)),
        const SizedBox(width: 16),
        Expanded(
            child: _buildMetricTile(
                'Sync Speed', '$syncSpeed MB/s', Icons.speed)),
        const SizedBox(width: 16),
        Expanded(
            child: _buildMetricTile(
                'Total Uptime', '$uptime%', Icons.trending_up)),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  )),
        ],
      ),
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
    const displayCapacity = 100 * 1024 * 1024 * 1024; // 100 GB

    final categories = _buildStorageCategories(byType);
    final usedBytes = categories.fold<int>(0, (sum, c) => sum + c.$2);
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
              (c) => _buildCategoryRow(c.$1, c.$2, c.$3, c.$4)),
        ],
      ),
    );
  }

  List<(String, int, IconData, int)> _buildStorageCategories(
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
      ('Documents', application, Icons.description, application),
      ('Media', image + video + audio, Icons.perm_media, image + video + audio),
      ('Research', text, Icons.auto_stories, text),
      ('Snippets', otherKeys, Icons.note, otherKeys),
    ];
  }

  Widget _buildCategoryRow(
      String label, int count, IconData icon, int fileCount) {
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

  Widget _buildRecentActivity() {
    if (_loadingActivity) {
      return _buildCard(
        child: const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_activityError != null) {
      return _buildCard(
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Activity data unavailable',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      );
    }

    final entries = _activity?['entries'] as List<dynamic>? ?? [];
    final total = (_activity?['total'] as num?)?.toInt() ?? 0;

    if (entries.isEmpty) {
      return _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Recent Activity',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text('No recent activity',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ],
        ),
      );
    }

    final hasMore = total > entries.length;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          ...entries.take(5).map((e) => _buildActivityEntry(
                e as Map<String, dynamic>,
              )),
          if (hasMore) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View Archive'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityEntry(Map<String, dynamic> entry) {
    final iconName = entry['icon'] as String? ?? 'auto_fix_high';
    final description = entry['description'] as String? ?? '';
    final timestamp = entry['timestamp'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_materialIcon(iconName), size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(description,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 8),
          Text(
            _relativeTime(timestamp),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  IconData _materialIcon(String name) {
    switch (name) {
      case 'add_circle':
        return Icons.add_circle_outline;
      case 'cloud_sync':
        return Icons.cloud_sync;
      case 'task_alt':
        return Icons.task_alt;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.auto_fix_high;
    }
  }

  String _relativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${diff.inDays ~/ 7}w ago';
    } catch (_) {
      return '';
    }
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
