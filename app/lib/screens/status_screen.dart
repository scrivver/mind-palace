import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/status_provider.dart';
import '../utils/format.dart';

class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(storageStatsProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(storageStatsProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 32),
              _buildStorageCapacity(context, stats),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sanctuary Health',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
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

  Widget _buildStorageCapacity(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> statsValue,
  ) {
    if (statsValue.isLoading) {
      return _buildCard(
        context,
        child: const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (statsValue.hasError || !statsValue.hasValue) {
      return _buildCard(
        context,
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Storage data unavailable',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final stats = statsValue.value!;
    final byType = stats['by_type'] as Map<String, dynamic>? ?? {};
    final fileCount = (stats['file_count'] as num?)?.toInt() ?? 0;
    final totalSize = (stats['total_size'] as num?)?.toInt() ?? 0;

    final categories = _buildStorageCategories(byType);
    final usedBytes = totalSize;

    return _buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Storage Used',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            FormatUtils.formatBytes(usedBytes),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Total files: $fileCount',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...categories.map(
            (c) => _buildCategoryRow(context, c.$1, c.$2, c.$3),
          ),
        ],
      ),
    );
  }

  List<(String, IconData, int)> _buildStorageCategories(
    Map<String, dynamic> byType,
  ) {
    final image = (byType['image'] as num?)?.toInt() ?? 0;
    final video = (byType['video'] as num?)?.toInt() ?? 0;
    final audio = (byType['audio'] as num?)?.toInt() ?? 0;
    final application = (byType['application'] as num?)?.toInt() ?? 0;
    final text = (byType['text'] as num?)?.toInt() ?? 0;
    final otherKeys = byType.keys
        .where(
          (k) =>
              !['image', 'video', 'audio', 'application', 'text'].contains(k),
        )
        .fold<int>(0, (sum, k) => sum + ((byType[k] as num?)?.toInt() ?? 0));

    return [
      ('Documents', Icons.description, application),
      ('Media', Icons.perm_media, image + video + audio),
      ('Research', Icons.auto_stories, text),
      ('Snippets', Icons.note, otherKeys),
    ];
  }

  Widget _buildCategoryRow(
    BuildContext context,
    String label,
    IconData icon,
    int fileCount,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            '$fileCount files',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
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
}
