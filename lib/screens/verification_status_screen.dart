// lib/screens/verification_status_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:helpify/providers/user_provider.dart';
import 'package:helpify/widgets/empty_state_widget.dart';
import 'package:helpify/screens/verification_center_screen.dart'; // To navigate to the upload screen

class VerificationStatusScreen extends StatelessWidget {
  const VerificationStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the user's status from the UserProvider for real-time updates
    final userStatus = Provider.of<UserProvider>(context).user?.verificationStatus ?? 'not_verified';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Status'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildContentForStatus(context, userStatus, theme),
        ),
      ),
    );
  }

  // This widget displays the correct status message and provides an action button if needed.
  Widget _buildContentForStatus(BuildContext context, String status, ThemeData theme) {
    switch (status) {
      case 'verified':
        return const EmptyStateWidget(
          icon: Icons.verified_user,
          title: "You're Verified!",
          message: "Congratulations, you are a trusted member of the Helpify community.",
        );
      case 'pending':
        return const EmptyStateWidget(
          icon: Icons.hourglass_top_rounded,
          title: "Documents Under Review",
          message: "We have received your documents. The review process usually takes 1-2 business days. We'll notify you once it's complete.",
        );
      case 'rejected':
        return EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: "Submission Rejected",
          message: "There was an issue with your previous submission. Please upload clear, valid documents.",
          actionButton: ElevatedButton.icon(
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Re-submit Documents'),
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const VerificationCenterScreen(),
              ));
            },
          ),
        );
      case 'not_verified':
      default:
        return EmptyStateWidget(
          icon: Icons.shield_outlined,
          title: "Become a Trusted Member",
          message: "Verify your profile to unlock full access to Helper features and build trust within the community.",
          actionButton: ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Start Verification Process'),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const VerificationCenterScreen(),
              ));
            },
          ),
        );
    }
  }
}