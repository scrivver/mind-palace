import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/engram_file.dart';
import '../providers/file_detail_provider.dart';
import '../providers/service_providers.dart';
import '../utils/format.dart';
import '../widgets/file_detail/delete_dialog.dart';
import '../widgets/file_detail/extracted_text_dialog.dart';
import '../widgets/file_detail/image_preview.dart';
import '../widgets/file_detail/pdf_preview.dart';

class FileDetailScreen extends ConsumerStatefulWidget {
  final String fileId;
  final void Function({bool deleted}) onBack;

  const FileDetailScreen({
    super.key,
    required this.fileId,
    required this.onBack,
  });

  @override
  ConsumerState<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends ConsumerState<FileDetailScreen> {
  Future<void> _download(EngramFile file) async {
    try {
      final reliquary = await ref.read(reliquaryServiceProvider.future);
      final url = await reliquary.presignDownloadForSave(file.filePath);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to download file')));
    }
  }

  Future<void> _copyLink(EngramFile file) async {
    try {
      final reliquary = await ref.read(reliquaryServiceProvider.future);
      final url = await reliquary.presignDownload(file.filePath);
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to get link')));
    }
  }

  Future<void> _delete(EngramFile file) async {
    final confirm = await showDeleteDialog(context, file.filename);
    if (confirm != true) return;

    try {
      final reliquary = await ref.read(reliquaryServiceProvider.future);
      await reliquary.deleteFile(file.filePath);
      if (!mounted) return;
      widget.onBack(deleted: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete file')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(fileDetailProvider(widget.fileId));

    return file.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildError(context, error),
      data: (file) => _buildContent(context, file),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load file',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  ref.invalidate(fileDetailProvider(widget.fileId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, EngramFile file) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildHeader(context),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: isWide
                  ? _buildWideLayout(context, file)
                  : _buildNarrowLayout(context, file),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => widget.onBack(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Icon(
          Icons.arrow_back,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, EngramFile file) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 7, child: _buildLeftColumn(context, file)),
          const SizedBox(width: 24),
          Expanded(flex: 5, child: _buildRightColumn(context, file)),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context, EngramFile file) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLeftColumn(context, file),
        const SizedBox(height: 24),
        _buildRightColumn(context, file),
      ],
    );
  }

  Widget _buildLeftColumn(BuildContext context, EngramFile file) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildPreview(context, file)),
        if (file.extractedText != null && file.extractedText!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildExtractedTextButton(context, file),
        ],
      ],
    );
  }

  Widget _buildPreview(BuildContext context, EngramFile file) {
    final theme = Theme.of(context);
    final isPdf = (file.mimeType ?? '').contains('pdf');
    final reliquary = ref.watch(reliquaryServiceProvider).valueOrNull;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: reliquary == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : isPdf
          ? PdfPreview(filePath: file.filePath, reliquary: reliquary)
          : ImagePreview(
              filePath: file.filePath,
              isImage: file.isImage,
              mimeType: file.mimeType,
              filename: file.filename,
              reliquary: reliquary,
            ),
    );
  }

  Widget _buildExtractedTextButton(BuildContext context, EngramFile file) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () =>
            showExtractedTextDialog(context, file.extractedText ?? ''),
        icon: const Icon(Icons.description_outlined, size: 18),
        label: const Text('View Extracted Text'),
        style: OutlinedButton.styleFrom(
          textStyle: theme.textTheme.labelLarge,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          foregroundColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildRightColumn(BuildContext context, EngramFile file) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(file.filename, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Last accessed ${FormatUtils.relativeTime(file.mtime)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildTags(context, file),
          const SizedBox(height: 24),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 24),
          _buildMetaGrid(context, file),
          const Spacer(),
          _buildActions(context, file),
        ],
      ),
    );
  }

  Widget _buildTags(BuildContext context, EngramFile file) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tags = file.tags;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...tags.asMap().entries.map(
          (entry) => Container(
            key: ValueKey(entry.value),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: entry.key == 0 ? cs.primary : cs.outline,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: entry.key == 0 ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '+ Add Tag',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaGrid(BuildContext context, EngramFile file) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metaField(theme, 'Type', file.mimeType ?? '\u2014'),
        const SizedBox(height: 20),
        _metaField(theme, 'Size', file.formattedSize),
        const SizedBox(height: 20),
        if (file.pageCount != null) ...[
          _metaField(theme, 'Pages', '${file.pageCount} Plates'),
          const SizedBox(height: 20),
        ],
        _metaField(
          theme,
          'Device',
          file.deviceName.isNotEmpty ? file.deviceName : '\u2014',
        ),
        const SizedBox(height: 20),
        _metaField(theme, 'Created', _formatDateTime(file.createdAt)),
        if (file.hash.isNotEmpty) ...[
          const SizedBox(height: 20),
          _metaField(theme, 'SHA-256', file.hash),
        ],
      ],
    );
  }

  Widget _metaField(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: label == 'SHA-256'
                ? theme.colorScheme.onSurfaceVariant
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, EngramFile file) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => _download(file),
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text('Download'),
                  style: FilledButton.styleFrom(
                    textStyle: theme.textTheme.labelLarge,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _copyLink(file),
                  icon: const Icon(Icons.link, size: 20),
                  label: const Text('Copy Link'),
                  style: OutlinedButton.styleFrom(
                    textStyle: theme.textTheme.labelLarge,
                    side: BorderSide(color: cs.primary),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _delete(file),
            icon: const Icon(Icons.delete, size: 20),
            label: const Text('Delete from Vault'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error),
              textStyle: theme.textTheme.labelLarge,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final y = local.year;
    final m = months[local.month - 1];
    final d = local.day;
    final mm = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final h12 = local.hour == 0
        ? 12
        : (local.hour > 12 ? local.hour - 12 : local.hour);
    return '$m $d, $y \u2022 $h12:$mm $ampm';
  }
}
