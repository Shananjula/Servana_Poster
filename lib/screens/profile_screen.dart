import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:servana/providers/user_provider.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/screens/edit_profile_screen.dart';
import 'package:servana/screens/wallet_screen.dart';
import 'package:servana/screens/skill_quests_screen.dart';
import 'package:servana/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/screens/verification_status_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final HelpifyUser? user = userProvider.user;
        if (user == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return _buildProfileScaffold(context, user);
      },
    );
  }

  Widget _buildProfileScaffold(BuildContext context, HelpifyUser user) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("My Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _ProfileHeaderCard(user: user),
            const SizedBox(height: 16),
            if (user.profileCompletion < 1.0)
              _ProfileCompletionCard(completion: user.profileCompletion),
            const SizedBox(height: 16),
            _ActionMenu(user: user),
            if (user.isHelper == true) ...[
              const SizedBox(height: 16),
              _HelperInfoSection(user: user),
            ],
            const SizedBox(height: 24),
            _LogoutButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final HelpifyUser user;
  const _ProfileHeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isVerified = user.verificationStatus == 'verified';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
                  Tooltip(
                    message: "Verified Helper (Tier: ${user.verificationTier.name})",
                    child: const Icon(Icons.verified, color: Colors.blue, size: 22),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            if (user.email != null) Text(user.email!, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),
            if (user.isHelper == true) ...[
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(value: user.averageRating.toStringAsFixed(1), label: "Rating"),
                  _StatItem(value: user.trustScore.toString(), label: "Trust Score"),
                  _StatItem(value: user.ratingCount.toString(), label: "Jobs Done"),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}

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

class _ProfileCompletionCard extends StatelessWidget {
  final double completion;
  const _ProfileCompletionCard({required this.completion});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.teal.withOpacity(0.3))),
      color: Colors.teal.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Profile Strength", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
            const SizedBox(height: 12),
            LinearPercentIndicator(
              lineHeight: 12.0,
              percent: completion,
              barRadius: const Radius.circular(6),
              backgroundColor: Colors.grey.shade300,
              progressColor: Colors.teal,
            ),
            const SizedBox(height: 8),
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

// --- THIS WIDGET IS NOW FIXED ---
class _ActionMenu extends StatelessWidget {
  final HelpifyUser user;
  const _ActionMenu({required this.user});

  @override
  Widget build(BuildContext context) {
    final bool isHelper = user.isHelper ?? false;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          if (isHelper)
          // Use a Consumer to get the latest state from the UserProvider
            Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                bool isHelperMode = userProvider.activeMode == AppMode.helper;
                return SwitchListTile(
                  title: Text(isHelperMode ? "Helper Mode" : "Poster Mode", style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(isHelperMode ? "You are seeing available tasks" : "You can now post new tasks"),
                  value: isHelperMode, // Value is now correctly from the provider
                  onChanged: (value) => context.read<UserProvider>().switchMode(), // Action now calls the provider
                  secondary: const Icon(Icons.work_outline_rounded),
                );
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.work_outline_rounded),
              title: const Text("Become a Helper", style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () { /* TODO: Navigate to helper onboarding */ },
            ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text("My Wallet", style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
          ),
          if (isHelper) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text("My Verification", style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationStatusScreen())),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text("Skill Quests", style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkillQuestsScreen())),
            ),
          ],
        ],
      ),
    );
  }
}

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
            Text("My Professional Profile", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 24),

            if (user.bio != null && user.bio!.isNotEmpty) ...[
              _buildInfoRow(context, Icons.person_outline, "About Me", user.bio!),
              const SizedBox(height: 16),
            ],

            if (user.skills.isNotEmpty) ...[
              _buildInfoRowWithChips(context, Icons.construction, "Skills", user.skills),
              const SizedBox(height: 16),
            ],

            if (user.qualifications != null && user.qualifications!.isNotEmpty) ...[
              _buildInfoRow(context, Icons.school_outlined, "Qualifications", user.qualifications!),
              const SizedBox(height: 16),
            ],
            if (user.experience != null && user.experience!.isNotEmpty) ...[
              _buildInfoRow(context, Icons.work_history_outlined, "Experience", user.experience!),
              const SizedBox(height: 16),
            ],
            if (user.videoIntroUrl != null && user.videoIntroUrl!.isNotEmpty) ...[
              const Text("Video Introduction", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final url = Uri.parse(user.videoIntroUrl!);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                child: Row(children: [
                  Icon(Icons.play_circle_outline, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text("Watch Helper's Introduction", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            if (user.portfolioImageUrls.isNotEmpty) ...[
              const Text("Portfolio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: user.portfolioImageUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(user.portfolioImageUrls[index], width: 100, height: 100, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRowWithChips(BuildContext context, IconData icon, String title, List<String> chips) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: chips.map((chip) => Chip(label: Text(chip))).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.logout),
      label: const Text('Logout'),
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade700,
        minimumSize: const Size(double.infinity, 50),
        side: BorderSide(color: Colors.red.shade200),
      ),
    );
  }
}