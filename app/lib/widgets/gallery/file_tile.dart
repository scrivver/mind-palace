import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/engram_file.dart';
import '../../reliquary_service.dart';
import '../../utils/format.dart';

class FileTile extends StatefulWidget {
  final EngramFile file;
  final ReliquaryService reliquary;
  final VoidCallback onTap;
  final String? displayName;
  final String? locationLabel;

  const FileTile({
    super.key,
    required this.file,
    required this.reliquary,
    required this.onTap,
    this.displayName,
    this.locationLabel,
  });

  @override
  State<FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<FileTile>
    with AutomaticKeepAliveClientMixin<FileTile> {
  Uint8List? _thumbBytes;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!_supportsThumbnail(widget.file.mimeType ?? '')) return;
    final key = ReliquaryService.thumbnailKeyFor(widget.file.filePath);
    if (key == null) return;
    // A remount after the shell rebuilt this screen usually finds the bytes
    // already cached; taking them synchronously paints the thumbnail on the
    // first frame instead of flashing the placeholder.
    _thumbBytes = widget.reliquary.cachedContent(key);
    if (_thumbBytes == null) _loadThumbnail(key);
  }

  bool _supportsThumbnail(String mime) =>
      mime.startsWith('image/') ||
      mime.startsWith('video/') ||
      mime == 'application/pdf';

  Future<void> _loadThumbnail(String key) async {
    try {
      // Fetched through the client rather than by URL: /storage/* is behind
      // forward_auth and an <img> request carries no bearer token.
      final bytes = await widget.reliquary.fetchContent(key);
      if (mounted) setState(() => _thumbBytes = bytes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
                child: Container(
                  color: theme.colorScheme.surfaceContainer,
                  child: _thumbBytes != null
                      ? Image.memory(
                          _thumbBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, _, _) => _fileIcon(context),
                        )
                      : _fileIcon(context),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.displayName ?? widget.file.filename,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.locationLabel != null &&
                      widget.locationLabel!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.locationLabel!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _typeBadge(context, widget.file.mimeType ?? ''),
                      const SizedBox(width: 6),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        FormatUtils.formatBytes(widget.file.size),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'Space Mono',
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        FormatUtils.relativeTime(widget.file.mtime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'Inter',
                          fontStyle: FontStyle.italic,
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
        iconForMime(widget.file.mimeType ?? ''),
        size: 36,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _typeBadge(BuildContext context, String mime) {
    final theme = Theme.of(context);
    final label = _shortType(mime);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'Space Mono',
          fontSize: 10,
          height: 1.3,
          color: theme.colorScheme.primary,
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
    if (mime.contains('text') ||
        mime.contains('markdown') ||
        mime.contains('md')) {
      return 'TXT';
    }
    if (mime.contains('javascript') ||
        mime.contains('python') ||
        mime.contains('json') ||
        mime.contains('html') ||
        mime.contains('xml')) {
      return 'CODE';
    }
    return 'FILE';
  }
}
