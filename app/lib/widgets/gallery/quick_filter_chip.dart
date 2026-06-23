import 'package:flutter/material.dart';

class QuickFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const QuickFilterChip({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final fg = isActive ? cs.primary : cs.onSurfaceVariant;
    final bg = isActive ? cs.primaryContainer : cs.surfaceContainerLow;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: isActive ? cs.primary : cs.outlineVariant.withAlpha(76),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'Space Grotesk',
                fontSize: 11,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
