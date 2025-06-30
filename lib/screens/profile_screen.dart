// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:helpify/providers/user_provider.dart';
import 'package:helpify/models/user_model.dart';
import 'package:helpify/screens/edit_profile_screen.dart';
import 'package:helpify/screens/wallet_screen.dart';
import 'package:helpify/screens/skill_quests_screen.dart';
import 'package:helpify/screens/leaderboard_screen.dart';
import 'package:helpify/screens/settings_screen.dart';
import 'package:helpify/screens/verification_status_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatelessWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUserProfile = userId == null || userId == FirebaseAuth.instance.currentUser?.uid;

    if (isCurrentUserProfile) {
      return Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final HelpifyUser? user = userProvider.user;
          if (user == null) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return _buildProfileScaffold(context, user, true);
        },
      );
    } else {
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Scaffold(appBar: AppBar(), body: const Center(child: Text("User not found.")));
            }
            final user = HelpifyUser.fromFirestore(snapshot.data!);
            return _buildProfileScaffold(context, user, false);
          }
      );
    }
  }

  Widget _buildProfileScaffold(BuildContext context, HelpifyUser user, bool isCurrentUserProfile) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isCurrentUserProfile ? "My Profile" : user.displayName ?? "Profile"),
        actions: [
          if (isCurrentUserProfile)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _ProfileHeader(user: user, isCurrentUser: isCurrentUserProfile),
            const SizedBox(height: 16),
            if (user.isHelper == true) _HelperStats(user: user),
            if (isCurrentUserProfile) _ActionMenu(),
            if (user.isHelper == true) _HelperInfoSection(user: user),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final HelpifyUser user;
  final bool isCurrentUser;

  const _ProfileHeader({required this.user, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: user.photoURL != null && user.photoURL!.isNotEmpty ? NetworkImage(user.photoURL!) : null,
            child: user.photoURL == null || user.photoURL!.isEmpty ? const Icon(Icons.person, size: 50) : null,
          ),
          const SizedBox(height: 16),
          Text(user.displayName ?? "Helpify User", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (isCurrentUser && user.email != null)
            Text(user.email!, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),
          if(user.isHelper == true)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Chip(
                avatar: Icon(Icons.verified_user, color: theme.colorScheme.primary, size: 18),
                label: Text("Verified Helper", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              ),
            ),
          const SizedBox(height: 24),
          if (isCurrentUser) ...[
            LinearPercentIndicator(
              lineHeight: 18.0,
              percent: user.profileCompletion,
              center: Text(
                "${(user.profileCompletion * 100).toStringAsFixed(0)}% Complete",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              barRadius: const Radius.circular(10),
              backgroundColor: Colors.grey.shade300,
              progressColor: theme.colorScheme.primary,
              animation: true,
            ),
            if (user.profileCompletion < 1.0)
              TextButton(
                child: const Text("Complete your profile"),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              )
          ]
        ],
      ),
    );
  }
}

class _HelperStats extends StatelessWidget {
  final HelpifyUser user;
  const _HelperStats({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.star_rounded,
                value: user.averageRating.toStringAsFixed(1),
                label: "${user.ratingCount} Reviews",
                color: Colors.amber,
              ),
              _StatItem(
                icon: Icons.shield_rounded,
                value: user.trustScore.toString(),
                label: "Trust Score",
                color: Colors.green,
              ),
              _StatItem(
                icon: Icons.check_circle_rounded,
                value: user.commissionFreeTasksCompleted.toString(),
                label: "Tasks Done",
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatItem({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ],
    );
  }
}

class _ActionMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("My Account", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 24),
          _ActionCard(title: "My Wallet", icon: Icons.account_balance_wallet_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()))),
          _ActionCard(title: "Edit Profile", icon: Icons.edit_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
          _ActionCard(
            title: "My Verification",
            icon: Icons.shield_outlined,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationStatusScreen())),
          ),
          _ActionCard(title: "Skill Quests", icon: Icons.flag_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkillQuestsScreen()))),
          _ActionCard(title: "App Settings", icon: Icons.settings_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionCard({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _HelperInfoSection extends StatelessWidget {
  final HelpifyUser user;
  const _HelperInfoSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Helper Information", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 24),
          if(user.skills.isNotEmpty) ...[
            const Text("My Skills", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: user.skills.map((skill) => Chip(label: Text(skill))).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if(user.badges.isNotEmpty) ...[
            const Text("My Badges", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              // --- THIS IS THE CORRECTED LINE ---
              children: user.badges.map((badge) => Chip(
                avatar: const Icon(Icons.verified, color: Colors.white, size: 18),
                label: Text(badge, style: const TextStyle(color: Colors.white)),
                backgroundColor: theme.colorScheme.secondary,
              )).toList(), // Added .toList() here
              // --- END OF CORRECTION ---
            ),
          ] else
            const Text("Complete Skill Quests to earn cool badges!"),
        ],
      ),
    );
  }
}