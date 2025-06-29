import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- THIS IMPORT FIXES THE ERRORS
import 'package:helpify/providers/user_provider.dart';
import 'package:helpify/models/user_model.dart';
import 'package:helpify/screens/edit_profile_screen.dart';
import 'package:helpify/screens/wallet_screen.dart';
import 'package:helpify/screens/skill_quests_screen.dart';
import 'package:helpify/screens/leaderboard_screen.dart';
import 'package:helpify/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final user = HelpifyUser.fromFirestore(snapshot.data! as DocumentSnapshot<Map<String, dynamic>>);
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
            _buildProfileHeader(context, user, isCurrentUserProfile),
            const SizedBox(height: 16),
            if (isCurrentUserProfile) _buildActionMenu(context),
            _buildHelperSection(context, user),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, HelpifyUser user, bool isCurrentUserProfile) {
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
          const SizedBox(height: 8),
          if (isCurrentUserProfile)
            Text(user.email ?? "No email provided", style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),

          if (isCurrentUserProfile) ...[
            const SizedBox(height: 24),
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
            TextButton(
              child: const Text("Complete your profile"),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildActionCard(context, "My Wallet", Icons.account_balance_wallet_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()))),
          _buildActionCard(context, "Edit Profile", Icons.edit_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
          _buildActionCard(context, "Helpify Heroes", Icons.leaderboard_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()))),
          _buildActionCard(context, "Skill Quests", Icons.flag_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkillQuestsScreen()))),
          _buildActionCard(context, "App Settings", Icons.settings_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
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

  Widget _buildHelperSection(BuildContext context, HelpifyUser user) {
    if (user.isHelper != true) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("My Helper Profile", style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          if(user.badges.isNotEmpty) ...[
            const Text("My Badges:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: user.badges.map((badge) => Chip(
                avatar: const Icon(Icons.verified_user, color: Colors.white, size: 18),
                label: Text(badge, style: const TextStyle(color: Colors.white)),
                backgroundColor: Theme.of(context).colorScheme.secondary,
              )).toList(),
            ),
          ] else
            const Text("Complete Skill Quests to earn cool badges!"),
        ],
      ),
    );
  }
}
