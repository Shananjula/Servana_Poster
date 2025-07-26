import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servana/providers/user_provider.dart';
import 'package:servana/widgets/document_upload_tile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DocumentUploadStep extends StatelessWidget {
  final VoidCallback onContinue;

  const DocumentUploadStep({super.key, required this.onContinue});

  // A helper function to check if all required documents are uploaded.
  bool _areAllDocumentsUploaded(BuildContext context) {
    final user = context.read<UserProvider>().user;
    if (user == null) return false;
    // Add all your required document URLs here
    return (user.nicFrontUrl != null && user.nicFrontUrl!.isNotEmpty) &&
        (user.nicBackUrl != null && user.nicBackUrl!.isNotEmpty) &&
        (user.policeClearanceUrl != null && user.policeClearanceUrl!.isNotEmpty);
  }

  Future<void> _saveAndContinue(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'onboardingStep': 2,
      });
      onContinue();
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<UserProvider>().user;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Upload Your Documents",
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            "For security and trust, we need to verify your identity. Your data is kept safe.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                DocumentUploadTile(
                  documentName: "National ID - Front",
                  documentType: "nicFrontUrl",
                  icon: Icons.badge_outlined,
                  initialUrl: user?.nicFrontUrl,
                ),
                const SizedBox(height: 16),
                DocumentUploadTile(
                  documentName: "National ID - Back",
                  documentType: "nicBackUrl",
                  icon: Icons.badge_outlined,
                  initialUrl: user?.nicBackUrl,
                ),
                const SizedBox(height: 16),
                DocumentUploadTile(
                  documentName: "Police Clearance Report",
                  documentType: "policeClearanceUrl",
                  icon: Icons.local_police_outlined,
                  initialUrl: user?.policeClearanceUrl,
                ),
                // Add more DocumentUploadTile widgets here for other documents
                // e.g., Driving License, Proof of Address, etc.
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            // The button is enabled only when all documents are uploaded.
            onPressed: _areAllDocumentsUploaded(context) ? () => _saveAndContinue(context) : null,
            child: const Text("Save & Continue"),
          ),
        ],
      ),
    );
  }
}
