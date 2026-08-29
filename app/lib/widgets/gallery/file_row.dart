import 'package:flutter/material.dart';

import 'gallery_view_model.dart';

class FileRow extends StatelessWidget {
  final GalleryFileProjection projection;
  final VoidCallback onTap;

  const FileRow({super.key, required this.projection, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final directory = projection.directoryPath.isEmpty
        ? 'Root'
        : projection.directoryPath;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Icon(
        iconForMime(projection.file.mimeType ?? ''),
        color: cs.onSurfaceVariant,
      ),
      title: Text(
        projection.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        directory,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypeBadge(label: projection.typeLabel),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                projection.sizeLabel,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'Space Mono',
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;

  const _TypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
}

IconData iconForMime(String mime) {
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime.startsWith('video/')) return Icons.videocam_outlined;
  if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
  if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
  if (mime.contains('zip') || mime.contains('tar') || mime.contains('rar')) {
    return Icons.archive_outlined;
  }
  if (mime.contains('text') || mime.contains('markdown')) {
    return Icons.article_outlined;
  }
  return Icons.insert_drive_file_outlined;
}
