// lib/screens/profile_screen.dart (Poster app only)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:servana/screens/verification_center_screen.dart';
import 'package:servana/screens/wallet_screen.dart';
import 'package:servana/screens/settings_screen.dart';
import 'package:servana/screens/legal_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in to view your profile.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final data = snap.data?.data() ?? const <String, dynamic>{};
          final displayName = (data['displayName'] as String?)?.trim() ?? 'User';
          final phone = (data['phoneNumber'] as String?) ?? (data['phone'] as String?) ?? '';
          final photoURL = (data['photoURL'] as String?) ?? (data['avatarUrl'] as String?);
          final trustScore = (data['trustScore'] as num?)?.toInt() ?? 0;
          final verificationStatus = (data['verificationStatus'] as String?) ?? 'not_started';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _HeaderCard(
                name: displayName,
                phone: phone,
                photoURL: photoURL,
                trustScore: trustScore,
                verificationStatus: verificationStatus,
              ),
              const SizedBox(height: 16),
              _ActionTile(
                icon: Icons.verified_user_outlined,
                label: 'Verification Center',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationCenterScreen())),
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Wallet',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.gavel_outlined,
                label: 'Legal',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen())),
              ),
              const SizedBox(height: 16),
              _BecomeHelperBanner(onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Play Store link coming soon…')),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.name, required this.phone, required this.photoURL, required this.trustScore, required this.verificationStatus});
  final String name;
  final String? phone;
  final String? photoURL;
  final int trustScore;
  final String verificationStatus;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: (photoURL != null && photoURL!.isNotEmpty) ? NetworkImage(photoURL!) : null,
              child: (photoURL == null || photoURL!.isEmpty) ? const Icon(Icons.person, size: 28) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  if (phone != null && phone!.isNotEmpty) Text(phone!, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Chip(text: 'Trust $trustScore%'),
                      const SizedBox(width: 8),
                      _Chip(text: 'Status: ${verificationStatus.toUpperCase()}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800)),
    );
  }
}

class _BecomeHelperBanner extends StatelessWidget {
  const _BecomeHelperBanner({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: cs.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.workspace_premium_outlined, color: cs.onTertiaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Become a Helper', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Install the Servana Helper app to get verified and start earning.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text('Play Store link • placeholder', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.primary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(onPressed: onTap, child: const Text('Get App')),
        ],
      ),
    );
  }
}