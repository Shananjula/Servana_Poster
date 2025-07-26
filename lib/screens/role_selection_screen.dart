import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/screens/edit_profile_screen.dart';
import 'package:servana/screens/home_screen.dart';
import 'package:servana/screens/service_selection_screen.dart'; // <-- UPDATED IMPORT

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _selectRole(BuildContext context, bool isHelper) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Set the user's role. We will mark selection as complete later.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isHelper': isHelper,
      }, SetOptions(merge: true));

      if (!context.mounted) return;

      // --- UPDATED NAVIGATION LOGIC ---
      if (isHelper) {
        // For helpers, the next step is to choose their service type.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ServiceSelectionScreen()),
        );
      } else {
        // For posters, mark selection as complete and go to profile setup.
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'hasCompletedRoleSelection': true,
        }, SetOptions(merge: true));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EditProfileScreen(isInitialSetup: true)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save role: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to Servana!',
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'How would you like to get started?',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 48),
              _buildRoleCard(
                context: context,
                icon: Icons.task_alt_rounded,
                title: 'I want to get tasks done',
                subtitle: 'Post jobs and find skilled people to help you.',
                onTap: () => _selectRole(context, false), // isHelper = false
              ),
              const SizedBox(height: 24),
              _buildRoleCard(
                context: context,
                icon: Icons.work_outline_rounded,
                title: 'I want to offer my services',
                subtitle: 'Find jobs, offer your skills, and start earning money.',
                onTap: () => _selectRole(context, true), // isHelper = true
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
