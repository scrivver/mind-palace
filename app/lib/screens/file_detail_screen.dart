import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../engram_service.dart';
import '../models/engram_file.dart';
import '../reliquary_service.dart';
import '../widgets/sidebar.dart';

class FileDetailScreen extends StatefulWidget {
  final EngramFile initial;
  final EngramService engram;
  final ReliquaryService reliquary;
  final VoidCallback onLogout;
  final String username;

  const FileDetailScreen({
    super.key,
    required this.initial,
    required this.engram,
    required this.reliquary,
    required this.onLogout,
    required this.username,
  });

  @override
  State<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends State<FileDetailScreen> {
  late EngramFile _file;
  bool _loadingDetail = true;

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
      setState(() {
        _file = full;
        _loadingDetail = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
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
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
              'Are you certain you wish to purge "${_file.filename}"? This action cannot be undone within the Mind Palace architecture.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Permanent Deletion'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    try {
      await widget.reliquary.deleteFile(_file.filePath);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to delete file')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
          child: Row(
            children: [
              Sidebar(
                username: widget.username,
                onLogout: widget.onLogout,
              ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildBreadcrumb(context),
                  const SizedBox(height: 16),
                  _buildPreview(context),
                  const SizedBox(height: 20),
                  _buildExtractedText(context),
                  const SizedBox(height: 20),
                  _buildFileInfo(context),
                  const SizedBox(height: 20),
                  _buildTags(context),
                  const SizedBox(height: 20),
                  _buildMetadata(context),
                  const SizedBox(height: 24),
                  _buildActions(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'Mind Palace',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (_file.isImage) {
      final maxH = MediaQuery.of(context).size.height * 0.45;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: FutureBuilder<String>(
          future: widget.reliquary.presignDownload(_file.filePath),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image.network(
                  snap.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _iconPreview(context),
                ),
              ),
            );
          },
        ),
      );
    }
    return _iconPreview(context);
  }

  Widget _iconPreview(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
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
      ),
    );
  }

  Widget _buildExtractedText(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadingDetail) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final text = _file.extractedText;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Extracted Analysis',
                  style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                'OCR Engine v4.2',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'Space Mono',
              height: 1.5,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfo(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _file.filename,
          style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(
          'Last accessed ${_relativeTime(_file.mtime)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFamily: 'Inter',
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildTags(BuildContext context) {
    final theme = Theme.of(context);
    final tags = _file.tags;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...tags.map(
          (t) => Chip(
            label: Text(
              t,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'Space Mono',
                fontSize: 11,
              ),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 14),
          label: Text(
            'Add Tag',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'Space Mono',
              fontSize: 11,
            ),
          ),
          onPressed: () {},
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  Widget _buildMetadata(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <_MetaRow>[
      _MetaRow('Type', _file.mimeType ?? '\u2014'),
      _MetaRow('Size', _file.formattedSize),
      if (_file.pageCount != null)
        _MetaRow('Pages', '${_file.pageCount} Plates'),
      _MetaRow('Device', _file.deviceName),
      _MetaRow('Created', _formatDateTime(_file.createdAt)),
      if (_file.hash.isNotEmpty)
        _MetaRow('SHA-256', '${_file.hash.substring(0, 16)}\u2026'),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...rows.map((r) => _buildMetaRow(context, r)),
        ],
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context, _MetaRow row) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              row.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              row.value,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Actions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              _actionButton(context, Icons.download, 'Download', _download),
              const SizedBox(width: 12),
              _actionButton(context, Icons.link, 'Copy Link', _copyLink),
              const SizedBox(width: 12),
              _actionButton(
                context,
                Icons.delete_outline,
                'Delete from Vault',
                _delete,
                color: theme.colorScheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onPressed, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    final fgColor = color ?? theme.colorScheme.primary;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: fgColor,
        side: BorderSide(color: fgColor.withValues(alpha: 0.4)),
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
    final h12 = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
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

class _MetaRow {
  final String label;
  final String value;
  const _MetaRow(this.label, this.value);
}
