import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../engram_service.dart';
import '../models/engram_file.dart';
import '../reliquary_service.dart';

/// Detail view for a single file. Shows full metadata, a preview (for images),
/// and any text extracted by the ingestion worker.
///
/// Pops with `true` when the user deletes the file so the caller can refresh.
class FileDetailScreen extends StatefulWidget {
  final EngramFile initial;
  final EngramService engram;
  final ReliquaryService reliquary;

  const FileDetailScreen({
    super.key,
    required this.initial,
    required this.engram,
    required this.reliquary,
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
      // Detail fetch failed; keep the list-level metadata we already have.
      setState(() => _loadingDetail = false);
    }
  }

  Future<void> _download() async {
    try {
      final url = await widget.reliquary.presignDownloadForSave(_file.filePath);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to download file')),
      );
    }
  }

  Future<void> _copyLink() async {
    try {
      final url = await widget.reliquary.presignDownload(_file.filePath);
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get link')),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Permanently remove "${_file.filename}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.reliquary.deleteFile(_file.filePath);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete file')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_file.filename, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Copy link',
            onPressed: _copyLink,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download',
            onPressed: _download,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            color: theme.colorScheme.error,
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPreview(context),
          const SizedBox(height: 16),
          _buildMetadata(context),
          const SizedBox(height: 16),
          _buildExtractedText(context),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (_file.isImage) {
      // Cap the preview at roughly half the viewport height so a huge image
      // doesn't push the rest of the detail content out of view. The user can
      // still pinch/zoom to inspect it in place.
      final maxH = MediaQuery.of(context).size.height * 0.5;
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
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          _iconForMime(_file.mimeType ?? ''),
          size: 72,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMetadata(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[
      _row('Type', _file.mimeType ?? '—'),
      _row('Size', _file.formattedSize),
      if (_file.pageCount != null) _row('Pages', _file.pageCount!.toString()),
      _row('Device', _file.deviceName),
      _row('Modified', _formatDateTime(_file.mtime)),
      _row('Uploaded', _formatDateTime(_file.createdAt)),
      if (_file.hash.isNotEmpty)
        _row('SHA-256', '${_file.hash.substring(0, 16)}…'),
    ];
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...rows,
            if (_file.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    _file.tags.map((t) => Chip(label: Text(t))).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedText(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadingDetail) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final text = _file.extractedText;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Extracted text', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SelectableText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium,
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

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
