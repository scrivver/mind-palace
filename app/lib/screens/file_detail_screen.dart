import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/engram_file.dart';
import '../providers/service_providers.dart';
import '../utils/format.dart';
import '../widgets/file_detail/delete_dialog.dart';
import '../widgets/file_detail/extracted_text_dialog.dart';
import '../widgets/file_detail/image_preview.dart';
import '../widgets/file_detail/pdf_preview.dart';

class FileDetailScreen extends ConsumerStatefulWidget {
  final EngramFile initial;
  final void Function({bool deleted}) onBack;

  const FileDetailScreen({
    super.key,
    required this.initial,
    required this.onBack,
  });

  @override
  ConsumerState<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends ConsumerState<FileDetailScreen> {
  late EngramFile _file;

  @override
  void initState() {
    super.initState();
    _file = widget.initial;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final engram = ref.read(engramServiceProvider).valueOrNull;
      if (engram == null) return;
      final full = await engram.getFile(widget.initial.id);
      if (!mounted) return;
      setState(() => _file = full);
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _download() async {
    try {
      final reliquary = ref.read(reliquaryServiceProvider).valueOrNull;
      if (reliquary == null) return;
      final url = await reliquary.presignDownloadForSave(_file.filePath);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to download file')));
    }
  }

  Future<void> _copyLink() async {
    try {
      final reliquary = ref.read(reliquaryServiceProvider).valueOrNull;
      if (reliquary == null) return;
      final url = await reliquary.presignDownload(_file.filePath);
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to get link')));
    }
  }

  Future<void> _delete() async {
    final confirm = await showDeleteDialog(context, _file.filename);
    if (confirm != true) return;

    try {
      final reliquary = ref.read(reliquaryServiceProvider).valueOrNull;
      if (reliquary == null) return;
      await reliquary.deleteFile(_file.filePath);
      if (!mounted) return;
      widget.onBack(deleted: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to delete file')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  ? _buildWideLayout(context)
                  : _buildNarrowLayout(context),
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

  Widget _buildWideLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 7, child: _buildLeftColumn(context)),
          const SizedBox(width: 24),
          Expanded(flex: 5, child: _buildRightColumn(context)),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLeftColumn(context),
        const SizedBox(height: 24),
        _buildRightColumn(context),
      ],
    );
  }

  Widget _buildLeftColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildPreview(context)),
        if (_file.extractedText != null && _file.extractedText!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildExtractedTextButton(context),
        ],
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    final isPdf = (_file.mimeType ?? '').contains('pdf');
    final reliquary = ref.read(reliquaryServiceProvider).valueOrNull;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: isPdf
          ? PdfPreview(filePath: _file.filePath, reliquary: reliquary!)
          : ImagePreview(
              filePath: _file.filePath,
              isImage: _file.isImage,
              mimeType: _file.mimeType,
              filename: _file.filename,
              reliquary: reliquary!,
            ),
    );
  }

  Widget _buildExtractedTextButton(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () =>
            showExtractedTextDialog(context, _file.extractedText ?? ''),
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

  Widget _buildRightColumn(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_file.filename, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Last accessed ${FormatUtils.relativeTime(_file.mtime)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildTags(context),
          const SizedBox(height: 24),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 24),
          _buildMetaGrid(context),
          const Spacer(),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildTags(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tags = _file.tags;

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

  Widget _buildMetaGrid(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metaField(theme, 'Type', _file.mimeType ?? '\u2014'),
        const SizedBox(height: 20),
        _metaField(theme, 'Size', _file.formattedSize),
        const SizedBox(height: 20),
        if (_file.pageCount != null) ...[
          _metaField(theme, 'Pages', '${_file.pageCount} Plates'),
          const SizedBox(height: 20),
        ],
        _metaField(
          theme,
          'Device',
          _file.deviceName.isNotEmpty ? _file.deviceName : '\u2014',
        ),
        const SizedBox(height: 20),
        _metaField(theme, 'Created', _formatDateTime(_file.createdAt)),
        if (_file.hash.isNotEmpty) ...[
          const SizedBox(height: 20),
          _metaField(theme, 'SHA-256', _file.hash),
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

  Widget _buildActions(BuildContext context) {
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
                  onPressed: _download,
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
                  onPressed: _copyLink,
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
            onPressed: _delete,
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final y = local.year;
    final m = months[local.month - 1];
    final d = local.day;
    final mm = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final h12 =
        local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    return '$m $d, $y \u2022 $h12:$mm $ampm';
  }
}
