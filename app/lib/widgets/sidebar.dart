import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int>? onDestinationChanged;
  final String username;
  final VoidCallback onLogout;

  const Sidebar({
    super.key,
    this.selectedIndex = 0,
    this.onDestinationChanged,
    required this.username,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          right: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mind Palace',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'DIGITAL SANCTUARY',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Column(
              children: [
                _NavItem(
                  icon: Icons.folder_open,
                  label: 'Vault',
                  selected: selectedIndex == 0,
                  onTap: onDestinationChanged != null
                      ? () => onDestinationChanged!(0)
                      : null,
                ),
                _NavItem(
                  icon: Icons.analytics_outlined,
                  label: 'Status',
                  selected: selectedIndex == 1,
                  onTap: onDestinationChanged != null
                      ? () => onDestinationChanged!(1)
                      : null,
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  selected: selectedIndex == 2,
                  onTap: onDestinationChanged != null
                      ? () => onDestinationChanged!(2)
                      : null,
                ),
                const Spacer(),
                Divider(
                  height: 1,
                  color: cs.outlineVariant,
                  indent: 24,
                  endIndent: 24,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: cs.primary,
                          foregroundColor: cs.surface,
                          child: Text(
                            _initials(username),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            username,
                            style: theme.textTheme.labelLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: onLogout,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: cs.error),
                        const SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: cs.error),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bg = selected ? cs.primaryContainer : Colors.transparent;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    final hoverBg = selected ? cs.primaryContainer : cs.surfaceContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: hoverBg,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
