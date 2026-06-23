import 'package:flutter/material.dart';

Future<bool?> showDeleteDialog(BuildContext context, String filename) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
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
            Text('Confirm Deletion', style: theme.textTheme.headlineMedium),
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
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: cs.error),
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
                onPressed: () => Navigator.pop(ctx, false),
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
    ),
  );
}
