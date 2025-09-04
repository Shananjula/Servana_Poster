// lib/screens/posterhomeshell.dart
//
// PosterHomeShell — 5-tab root shell for POSTER-ONLY app
// Tabs: Home • Browse • Activity • Chats • Profile
// - Bell (notifications) lives in each screen's AppBar; no chat icon in top bar.
// - Uses IndexedStack to preserve state between tabs.
// - No helper-side UI or role toggle here.
//
// Drop-in: returns same class name `PosterHomeShell` expected by main.dart.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Tabs
import 'package:servana/screens/home_screen.dart';
import 'package:servana/screens/browse_screen.dart';
import 'package:servana/screens/activity_screen.dart';
import 'package:servana/screens/chat_list_screen.dart';
import 'package:servana/screens/poster_profile_screen.dart';

// Optional providers
import 'package:servana/providers/user_provider.dart';

class PosterHomeShell extends StatefulWidget {
  const PosterHomeShell({super.key});

  @override
  State<PosterHomeShell> createState() => _PosterHomeShellState();
}

class _PosterHomeShellState extends State<PosterHomeShell> {
  int _index = 0;

  final _navKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  void _onTap(int i) {
    if (i == _index) {
      // Pop to first route of the current tab
      _navKeys[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _index = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force poster mode in shell (no helper UI exposed from here)
    final userProv = context.watch<UserProvider>();
    final isHelperMode = userProv.isHelperMode;
    if (isHelperMode) {
      // Soft guard: keep UI in poster mode
      // (We don't mutate provider here; just avoid showing helper-only UI)
    }

    final items = const [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.search_rounded, label: 'Browse'),
      _NavItem(icon: Icons.event_available_rounded, label: 'Activity'),
      _NavItem(icon: Icons.chat_bubble_rounded, label: 'Chats'),
      _NavItem(icon: Icons.person_rounded, label: 'Profile'),
    ];

    final pages = [
      const HomeScreen(),
      const BrowseScreen(),
      const ActivityScreen(),
      const ChatListScreen(),
      const PosterProfileScreen(),
    ];

    return WillPopScope(
      onWillPop: () async {
        final nav = _navKeys[_index].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: List.generate(pages.length, (i) {
            return Navigator(
              key: _navKeys[i],
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => pages[i],
                settings: settings,
              ),
            );
          }),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onTap,
          destinations: items
              .map((e) => NavigationDestination(
                    icon: Icon(e.icon),
                    label: e.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
