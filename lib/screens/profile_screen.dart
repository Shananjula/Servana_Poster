// lib/screens/profile_screen.dart - REDESIGNED

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servana/providers/user_provider.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/screens/edit_profile_screen.dart';
import 'package:servana/screens/wallet_screen.dart';
import 'package:servana/screens/skill_quests_screen.dart';
import 'package:servana/screens/settings_screen.dart';
import 'package:servana/screens/service_selection_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/screens/verification_status_screen.dart';


class ProfileScreen extends StatelessWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    // This logic to fetch the correct user remains the same
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

  // --- NEW: Redesigned Scaffold ---
  Widget _buildProfileScaffold(BuildContext context, HelpifyUser user, bool isCurrentUserProfile) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // A subtle off-white background
      appBar: AppBar(
        title: Text(isCurrentUserProfile ? "My Profile" : user.displayName ?? "Profile"),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            _ProfileHeaderCard(user: user, isCurrentUser: isCurrentUserProfile),
            const SizedBox(height: 16),
            if (isCurrentUserProfile && user.profileCompletion < 1.0)
              _ProfileCompletionCard(completion: user.profileCompletion),
            if (isCurrentUserProfile) ...[
              const SizedBox(height: 16),
              _ActionMenu(isHelper: user.isHelper ?? false),
            ],
            if (user.isHelper == true) ...[
              const SizedBox(height: 16),
              _HelperInfoSection(user: user),
            ],
            if(isCurrentUserProfile) ...[
              const SizedBox(height: 24),
              _LogoutButton(),
              const SizedBox(height: 24),
            ]
          ],
        ),
      ),
    );
  }
}

// --- NEW: Unified Header Card ---
class _ProfileHeaderCard extends StatelessWidget {
  final HelpifyUser user;
  final bool isCurrentUser;

  const _ProfileHeaderCard({required this.user, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isVerified = user.isHelper == true && user.verificationStatus == 'verified';

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 10,
            )
          ]
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: user.photoURL != null && user.photoURL!.isNotEmpty ? NetworkImage(user.photoURL!) : null,
            child: user.photoURL == null || user.photoURL!.isEmpty ? const Icon(Icons.person, size: 50) : null,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(user.displayName ?? "Servana User", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              if(isVerified) ...[
                const SizedBox(width: 8),
                const Icon(Icons.verified, color: Colors.blue, size: 22),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (isCurrentUser && user.email != null)
            Text(user.email!, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),

          if (user.isHelper == true) ...[
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  value: user.averageRating.toStringAsFixed(1),
                  label: "Rating",
                ),
                _StatItem(
                  value: user.trustScore.toString(),
                  label: "Trust Score",
                ),
                _StatItem(
                  value: user.commissionFreeTasksCompleted.toString(),
                  label: "Tasks Done",
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}

// --- NEW: More engaging StatItem ---
class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ],
    );
  }
}

// --- NEW: Dedicated Profile Completion Card ---
class _ProfileCompletionCard extends StatelessWidget {
  final double completion;
  const _ProfileCompletionCard({required this.completion});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Profile Strength", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LinearPercentIndicator(
              lineHeight: 12.0,
              percent: completion,
              barRadius: const Radius.circular(6),
              backgroundColor: Colors.grey.shade200,
              progressColor: Colors.teal,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              child: const Text("Complete your profile to build more trust"),
            )
          ],
        ),
      ),
    );
  }
}


// --- NEW: Reorganized and restyled Action Menu ---
class _ActionMenu extends StatelessWidget {
  final bool isHelper;
  const _ActionMenu({required this.isHelper});

  Widget _buildMenuTile({required String title, required IconData icon, required VoidCallback onTap, bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.teal),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDestructive ? Colors.redAccent : Colors.black87)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0, right: 16.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isHelper)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                bool isHelperMode = userProvider.activeMode == AppMode.helper;
                return SwitchListTile(
                  title: Text(isHelperMode ? "Helper Mode" : "Poster Mode", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(isHelperMode ? "You are seeing available tasks" : "You are seeing available helpers"),
                  value: isHelperMode,
                  onChanged: (value) => context.read<UserProvider>().switchMode(),
                );
              },
            ),
          )
        else
          Card(
            elevation: 0,
            color: Colors.teal.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: _buildMenuTile(
              title: "Become a Helper",
              icon: Icons.work_outline_rounded,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceSelectionScreen())),
            ),
          ),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              _buildMenuTile(title: "Edit Profile", icon: Icons.edit_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildMenuTile(title: "My Wallet", icon: Icons.account_balance_wallet_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()))),
              if(isHelper) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildMenuTile(title: "My Verification", icon: Icons.shield_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationStatusScreen()))),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildMenuTile(title: "Skill Quests", icon: Icons.flag_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkillQuestsScreen()))),
              ],
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildMenuTile(title: "App Settings", icon: Icons.settings_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
            ],
          ),
        )
      ],
    );
  }
}

// --- NEW: Helper Info moved to its own card ---
class _HelperInfoSection extends StatelessWidget {
  final HelpifyUser user;
  const _HelperInfoSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Helper Information", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if(user.skills.isNotEmpty) ...[
              const Text("My Skills", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: user.skills.map((skill) => Chip(label: Text(skill), padding: const EdgeInsets.all(4))).toList(),
              ),
              const SizedBox(height: 16),
            ],
            if(user.badges.isNotEmpty) ...[
              const Text("My Badges", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: user.badges.map((badge) => Chip(
                  avatar: const Icon(Icons.verified, color: Colors.white, size: 16),
                  label: Text(badge, style: const TextStyle(color: Colors.white)),
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                )).toList(),
              ),
            ] else
              const Text("Complete Skill Quests to earn cool badges!"),
          ],
        ),
      ),
    );
  }
}

// --- NEW: Dedicated Logout Button ---
class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.logout, color: Colors.redAccent),
      label: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
      },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}