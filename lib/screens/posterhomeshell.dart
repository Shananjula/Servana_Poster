// lib/screens/posterhomeshell.dart
//
// PosterHomeShell — 5-tab root shell for POSTER-ONLY app
// Tabs: Home • Browse • Activity • Chats • Profile
// - No Provider dependency (no UserProvider required)
// - Keeps tab state with IndexedStack
// - Tapping the active tab pops to its root

import 'package:flutter/material.dart';

// Tabs
import 'package:servana/screens/home_screen.dart';
import 'package:servana/screens/browse_screen.dart';
import 'package:servana/screens/activity_screen.dart';
import 'package:servana/screens/chat_list_screen.dart';
import 'package:servana/screens/poster_profile_screen.dart';

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
      _navKeys[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _index = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = const [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.search_rounded, label: 'Browse'),
      _NavItem(icon: Icons.event_available_rounded, label: 'Activity'),
      _NavItem(icon: Icons.chat_bubble_rounded, label: 'Chats'),
      _NavItem(icon: Icons.person_rounded, label: 'Profile'),
    ];

    final pages = const [
      HomeScreen(),
      BrowseScreen(),
      ActivityScreen(),
      ChatListScreen(),
      PosterProfileScreen(),
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
