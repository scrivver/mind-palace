import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Sidebar extends StatelessWidget {
  final int? selectedIndex;
  final ValueChanged<int>? onDestinationChanged;
  final String username;
  final VoidCallback onLogout;

  const Sidebar({
    super.key,
    this.selectedIndex,
    this.onDestinationChanged,
    required this.username,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationChanged ?? (_) {},
      labelType: NavigationRailLabelType.all,
      backgroundColor: theme.colorScheme.surface,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              radius: 20,
              child: Text(
                _initials(username),
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              username,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      trailing: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: IconButton(
          icon: const Icon(Icons.logout, size: 20),
          onPressed: onLogout,
          tooltip: 'Logout',
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.folder_open),
          label: Text('Vault'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.analytics),
          label: Text('Status'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
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
