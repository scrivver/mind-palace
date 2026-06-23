import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../engram_service.dart';
import '../models/engram_file.dart';
import '../reliquary_service.dart';

class FileDetailScreen extends StatefulWidget {
  final EngramFile initial;
  final EngramService engram;
  final ReliquaryService reliquary;
  final void Function({bool deleted}) onBack;

  const FileDetailScreen({
    super.key,
    required this.initial,
    required this.engram,
    required this.reliquary,
    required this.onBack,
  });

  @override
  State<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends State<FileDetailScreen> {
  late EngramFile _file;

  @override
  void initState() {
    super.initState();
    _file = widget.initial;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final full = await widget.engram.getFile(widget.initial.id);
      if (!mounted) return;
      setState(() => _file = full);
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _download() async {
    try {
      final url =
          await widget.reliquary.presignDownloadForSave(_file.filePath);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to download file')));
    }
  }

  Future<void> _copyLink() async {
    try {
      final url = await widget.reliquary.presignDownload(_file.filePath);
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteDialog(filename: _file.filename),
    );
    if (confirm != true) return;

    try {
      await widget.reliquary.deleteFile(_file.filePath);
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
        if (_file.extractedText != null &&
            _file.extractedText!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildExtractedTextButton(context),
        ],
      ],
    );
  }

  Future<Uint8List> _fetchPdfBytes() async {
    final url = await widget.reliquary.presignDownload(_file.filePath);
    final response = await http.get(Uri.parse(url));
    return response.bodyBytes;
  }

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    final isPdf = (_file.mimeType ?? '').contains('pdf');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: isPdf
          ? _buildPdfPreview(context)
          : _buildImagePreview(context),
    );
  }

  Widget _buildPdfPreview(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _fetchPdfBytes(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return PdfViewer(
          PdfDocumentRefData(
            snap.data!,
            sourceName: _file.filePath,
          ),
          params: PdfViewerParams(
            backgroundColor: const Color(0xFFFAFAFA),
            errorBannerBuilder: (_, error, stackTrace, ref) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load PDF',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    if (_file.isImage) {
      return FutureBuilder<String>(
        future: widget.reliquary.presignDownload(_file.filePath),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                constrained: false,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Image.network(
                    snap.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _iconPreview(context),
                  ),
                ),
              );
            },
          );
        },
      );
    }
    return Center(child: _iconPreview(context));
  }

  Widget _iconPreview(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconForMime(_file.mimeType ?? ''),
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            _file.filename,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedTextButton(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showExtractedTextDialog(context),
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

  void _showExtractedTextDialog(BuildContext context) {
    final theme = Theme.of(context);
    final screenH = MediaQuery.of(context).size.height;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: SizedBox(
          width: 560,
          height: screenH * 0.55,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Extracted Analysis',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'OCR Engine v4.2',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _file.extractedText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'Space Mono',
                          height: 1.5,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
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
          Text(
            _file.filename,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Last accessed ${_relativeTime(_file.mtime)}',
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

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'moments ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }
}

class _DeleteDialog extends StatelessWidget {
  final String filename;

  const _DeleteDialog({required this.filename});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Confirm Deletion',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Are you certain you wish to purge "$filename"? This action cannot be undone within the Mind Palace architecture.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                ),
                child: Text(
                  'Permanent Deletion',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onError,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.outline),
                ),
                child: Text(
                  'Cancel',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
