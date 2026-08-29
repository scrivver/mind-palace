import 'package:flutter/material.dart';

import 'gallery_view_model.dart';

class FolderRow extends StatelessWidget {
  final FolderEntry folder;
  final VoidCallback onTap;

  /// Phone density: the loaded-item count joins the subtitle so the trailing
  /// slot can be the chevron that says the row opens a folder.
  final bool compact;

  const FolderRow({
    super.key,
    required this.folder,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final countLabel =
        '${folder.count} loaded ${folder.count == 1 ? 'item' : 'items'}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Icon(Icons.folder, color: cs.primary),
      title: Text(
        folder.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        compact ? 'Folder \u00b7 $countLabel' : 'Folder',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: compact ? 11 : null,
          color: cs.onSurfaceVariant,
        ),
      ),
      trailing: compact
          ? Icon(Icons.chevron_right, color: cs.onSurfaceVariant)
          : Text(
              countLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
      onTap: onTap,
    );
  }
}
