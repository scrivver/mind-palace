import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../utils/format.dart';
import 'upload_progress.dart';

class UploadFileTile extends StatelessWidget {
  final PlatformFile file;

  /// What to show instead of the bare filename — the upload-relative path for
  /// a folder upload, so nested files stay distinguishable in the list.
  final String? label;
  final UploadProgress? progress;
  final VoidCallback? onRemove;

  const UploadFileTile({
    super.key,
    required this.file,
    this.label,
    this.progress,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = progress?.done == true;
    final isError = progress?.error == true;
    final isDuplicate = progress?.isDuplicate == true;
    final isUploading = progress != null && !isDone && !isError;

    IconData leadingIcon;
    Color? iconColor;
    if (isDone) {
      leadingIcon = isDuplicate ? Icons.content_copy : Icons.check_circle;
      iconColor = isDuplicate
          ? theme.colorScheme.tertiary
          : theme.colorScheme.primary;
    } else if (isError) {
      leadingIcon = Icons.error;
      iconColor = theme.colorScheme.error;
    } else {
      leadingIcon = _iconForName(file.name);
      iconColor = theme.colorScheme.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(leadingIcon, size: 22, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label ?? file.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${FormatUtils.formatBytes(file.size)} • ${progress?.status ?? "Pending"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: isError
                        ? theme.colorScheme.error
                        : isDone
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isUploading && progress!.fraction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(
                      value: progress!.fraction,
                      minHeight: 3,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isDone)
            Icon(
              Icons.more_vert,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            )
          else if (isError)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Retry',
              onPressed: () {},
              visualDensity: VisualDensity.compact,
            )
          else
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove',
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  IconData _iconForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.svg')) {
      return Icons.image;
    }
    if (lower.endsWith('.md') || lower.endsWith('.txt')) {
      return Icons.description;
    }
    if (lower.endsWith('.json') ||
        lower.endsWith('.js') ||
        lower.endsWith('.py') ||
        lower.endsWith('.dart') ||
        lower.endsWith('.html')) {
      return Icons.terminal;
    }
    if (lower.endsWith('.xlsx') ||
        lower.endsWith('.csv') ||
        lower.endsWith('.numbers')) {
      return Icons.table_chart;
    }
    return Icons.insert_drive_file;
  }
}
