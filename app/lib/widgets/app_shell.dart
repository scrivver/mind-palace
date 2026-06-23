import 'package:flutter/material.dart';

import 'sidebar.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final String username;
  final void Function(int) onDestinationChanged;
  final VoidCallback onLogout;

  const AppShell({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.username,
    required this.onDestinationChanged,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(
              selectedIndex: selectedIndex,
              onDestinationChanged: onDestinationChanged,
              username: username,
              onLogout: onLogout,
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
