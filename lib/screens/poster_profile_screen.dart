// lib/screens/poster_profile_screen.dart
//
// Poster Profile (with coin balance + Settings entry)
// - Header shows display name, phone, and coin balance (users/{uid}, wallets/{uid})
// - Big Settings button (opens SettingsScreen)
// - Quick actions: Coins (Top up), Shortlist
// - Helpful links: Edit profile, Legal/About, Logout

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:servana/screens/notifications_screen.dart';
import 'package:servana/screens/settings_screen.dart';
import 'package:servana/screens/top_up_screen.dart';
import 'package:servana/screens/shortlist_screen.dart';
import 'package:servana/screens/legal_screen.dart';
import 'package:servana/screens/settings_screen.dart' show EditProfileScreen;

class PosterProfileScreen extends StatelessWidget {
  const PosterProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Header: name, phone, coins, Edit/Settings buttons
          _ProfileHeader(uid: uid),

          const SizedBox(height: 16),
          // Quick actions
          Row(
            children: [
              _QuickAction(
                icon: Icons.settings_rounded,
                label: 'Settings',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              const SizedBox(width: 12),
              _QuickAction(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Coins',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TopUpScreen()),
                ),
              ),
              const SizedBox(width: 12),
              _QuickAction(
                icon: Icons.favorite_rounded,
                label: 'Shortlist',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShortlistScreen()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Text('Account', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          _tile(
            context,
            icon: Icons.person_rounded,
            title: 'Edit profile',
            subtitle: 'Name & basic info',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
          _tile(
            context,
            icon: Icons.receipt_long_rounded,
            title: 'Invoices & receipts',
            subtitle: 'Download past receipts',
            onTap: () {}, // wire if you add invoices screen
          ),

          const SizedBox(height: 16),
          Text('Help & legal', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          _tile(
            context,
            icon: Icons.description_rounded,
            title: 'Legal & terms',
            subtitle: 'Privacy policy and terms',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LegalScreen()),
            ),
          ),
          _tile(
            context,
            icon: Icons.info_rounded,
            title: 'About Servana',
            subtitle: 'Version info',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Servana',
              applicationVersion: '1.0.0',
              applicationLegalese: '© ${DateTime.now().year} Servana',
            ),
          ),

          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out')),
                );
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context,
      {required IconData icon,
        required String title,
        String? subtitle,
        required VoidCallback onTap}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outline.withOpacity(0.12)),
        ),
        tileColor: cs.surface,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle == null ? null : Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.uid});
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final userStream = uid == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    final walletStream = uid == null
        ? null
        : FirebaseFirestore.instance.collection('wallets').doc(uid).snapshots();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 28, child: Icon(Icons.person)),
          const SizedBox(width: 12),
          Expanded(
            child: uid == null
                ? const Text('Not signed in',
                style: TextStyle(fontWeight: FontWeight.w800))
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: userStream,
              builder: (context, snap) {
                final data = snap.data?.data() ?? {};
                final name = (data['displayName'] ?? '').toString().trim();
                final phone = (data['phone'] ??
                    FirebaseAuth.instance.currentUser?.phoneNumber ??
                    '')
                    .toString();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Your account' : name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          if (uid != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: walletStream,
              builder: (context, snap) {
                final coins = (snap.data?.data()?['coins'] ?? 0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Coins',
                        style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      coins.toString(),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          height: 80,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withOpacity(0.12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
