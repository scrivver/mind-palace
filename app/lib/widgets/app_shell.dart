import 'package:flutter/material.dart';

import '../utils/breakpoints.dart';
import 'sidebar.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final String username;
  final bool isAdmin;

  /// First path segment of the active route. On mobile it decides whether the
  /// bottom navigation bar is shown.
  final String segment;
  final void Function(int) onDestinationChanged;
  final VoidCallback onLogout;

  const AppShell({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.username,
    this.isAdmin = false,
    required this.segment,
    required this.onDestinationChanged,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobileWidth(context)) return _buildMobile(context);

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(
              selectedIndex: selectedIndex,
              onDestinationChanged: onDestinationChanged,
              username: username,
              isAdmin: isAdmin,
              onLogout: onLogout,
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.folder_open_outlined),
        selectedIcon: Icon(Icons.folder_open),
        label: 'Vault',
      ),
      const NavigationDestination(
        icon: Icon(Icons.analytics_outlined),
        selectedIcon: Icon(Icons.analytics),
        label: 'Status',
      ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
    ];

    // The file detail and upload screens are entered from the vault and own
    // the bottom edge with their own action bar, so the nav bar steps aside
    // rather than stacking two bars on a phone.
    final showNav = segment != 'file' && segment != 'upload';

    return Scaffold(
      body: child,
      bottomNavigationBar: showNav
          ? NavigationBar(
              selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
              onDestinationSelected: onDestinationChanged,
              destinations: destinations,
            )
          : null,
    );
  }
}
