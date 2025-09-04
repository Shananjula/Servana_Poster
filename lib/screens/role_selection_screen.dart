// lib/screens/role_selection_screen.dart
//
// Role Selection (first-time users)
// • Choose: Poster (hire helpers) OR Helper (offer services)
// • Writes users/{uid}.role = 'poster' | 'helper'
// • For helpers, also initializes:
//     uiMode: 'helper'          (Profile can switch view later)
//     verificationStatus: 'not_started'
//     isHelper: true
// • After save, this screen simply pops; AuthWrapper listens to the user doc
//   and will route to the right next screen (profile/onboarding/home).
//
// Safe fallbacks: guards auth, friendly errors, idempotent writes.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _busy = false;

  Future<void> _pick(String role) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _toast('Please sign in first.');
      return;
    }

    setState(() => _busy = true);
    try {
      final now = FieldValue.serverTimestamp();
      final patch = <String, dynamic>{
        'role': role,                 // 'poster' | 'helper'
        'updatedAt': now,
      };

      if (role == 'helper') {
        patch.addAll({
          'isHelper': true,
          'verificationStatus': 'not_started',
          // Default app view for helpers is helper mode; profile can flip later.
          'uiMode': 'helper',
        });
      } else {
        // Posters view as poster
        patch['uiMode'] = 'poster';
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        patch,
        SetOptions(merge: true),
      );

      if (!mounted) return;
      // Let AuthWrapper re-read user doc and navigate appropriately.
      Navigator.pop(context);
    } catch (e) {
      _toast('Could not set role: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your role'),
        centerTitle: true,
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Intro
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primary.withOpacity(0.12),
                  foregroundColor: cs.primary,
                  child: const Icon(Icons.account_circle_outlined),
                ),
                title: const Text('Welcome to Servana'),
                subtitle: const Text('Pick how you want to use the app. You can become a Helper later too.'),
              ),
            ),
            const SizedBox(height: 16),

            // Poster card
            _RoleCard(
              title: 'I need help (Poster)',
              subtitle:
              'Post tasks and hire trusted helpers. Browse by category, chat, and manage offers easily.',
              icon: Icons.person_search_outlined,
              color: Colors.indigo,
              actionText: 'Continue as Poster',
              onPressed: () => _pick('poster'),
              busy: _busy,
            ),
            const SizedBox(height: 12),

            // Helper card
            _RoleCard(
              title: 'I offer services (Helper)',
              subtitle:
              'Go live to get nearby jobs, build your profile, and earn. Verification keeps the marketplace safe.',
              icon: Icons.handyman_outlined,
              color: Colors.teal,
              actionText: 'Become a Helper',
              onPressed: () => _pick('helper'),
              busy: _busy,
            ),

            const SizedBox(height: 16),

            // Note
            Card(
              color: cs.surfaceContainerHigh,
              child: const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('You can always switch the app view later'),
                subtitle: Text('If you become a helper, the mode switch lives in your Profile.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.actionText,
    required this.onPressed,
    required this.busy,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String actionText;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: busy ? null : onPressed,
                icon: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_forward),
                label: Text(actionText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
