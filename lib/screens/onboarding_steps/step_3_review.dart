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

  /// Submits the user's profile for verification.
  /// This now performs a batch write to update the user's status AND create a new
  /// document in the 'verification_requests' collection for the admin panel.
  Future<void> _submitForVerification() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    // Use the UserProvider to get the most up-to-date user data
    final helpifyUser = context.read<UserProvider>().user;

    if (user == null || helpifyUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: User not found. Please restart the app.")),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Get a reference to the Firestore database
      final db = FirebaseFirestore.instance;

      // Create a batch
      final batch = db.batch();

      // 1. Define the reference for the user's document
      final userRef = db.collection('users').doc(user.uid);
      // Add the user document update to the batch
      batch.update(userRef, {
        'documentsSubmitted': true,
        'verificationStatus': 'pending',
        'onboardingStep': 3,
        'hasCompletedRoleSelection': true,
      });

      // 2. Define a reference for the NEW verification request document
      // Your admin panel is listening to this collection!
      final verificationRef = db.collection('verification_requests').doc();
      // Add the new verification request to the batch
      batch.set(verificationRef, {
        'userId': user.uid,
        'userName': helpifyUser.displayName, // Get name from the user model
        'status': 'pending_review', // The status your admin panel expects
        'submittedAt': FieldValue.serverTimestamp(),
        // Storing all document URLs in one request for easier review
        'documents': {
          'nicFrontUrl': helpifyUser.nicFrontUrl,
          'nicBackUrl': helpifyUser.nicBackUrl,
          'policeClearanceUrl': helpifyUser.policeClearanceUrl,
        },
        // You can add a general documentType or be more specific
        'documentType': 'Helper Onboarding',
      });

      // 3. Commit the batch to execute both operations at once
      await batch.commit();

      // The AuthWrapper will now automatically navigate the user.
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
    // Use 'watch' here to rebuild if user data changes
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
            "You have provided all the necessary information. Please submit your profile for review. We'll notify you once it's approved (usually within 1-2 business days).",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          // A summary of the provided info
          if (user != null) ...[
            Text("Selected Skills: ${user.skills.join(', ')}", textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text("Documents Uploaded: 3", textAlign: TextAlign.center),
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
