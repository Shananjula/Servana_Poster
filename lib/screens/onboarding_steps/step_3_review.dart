import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:servana/providers/user_provider.dart';

class ReviewSubmitStep extends StatefulWidget {
  const ReviewSubmitStep({super.key});

  @override
  State<ReviewSubmitStep> createState() => _ReviewSubmitStepState();
}

class _ReviewSubmitStepState extends State<ReviewSubmitStep> {
  bool _isLoading = false;

  Future<void> _submitForVerification() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // This is the final step. We set the status to 'pending'
        // which will be picked up by your backend Cloud Function.
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'verificationStatus': 'pending',
          'onboardingStep': 3, // Mark onboarding as complete
          'hasCompletedRoleSelection': true, // Final confirmation
        });
        // The AuthWrapper will now automatically navigate the user
        // to the VerificationStatusScreen.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Submission failed: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<UserProvider>().user;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
          const SizedBox(height: 24),
          Text(
            "Ready to Go!",
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            "You have provided all the necessary information. Please submit your profile for review. We'll notify you once it's approved (usually within 24 hours).",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          // You could add a summary of the provided info here if you like
          if (user != null) ...[
            Text("Selected Skills: ${user.skills.join(', ')}", textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text("Documents Uploaded: 3", textAlign: TextAlign.center),
          ],
          const SizedBox(height: 32),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _submitForVerification,
            child: const Text("Submit for Verification"),
          ),
        ],
      ),
    );
  }
}
