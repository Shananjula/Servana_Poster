import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servana/providers/user_provider.dart';
import 'package:servana/screens/home_screen.dart';
import 'package:servana/widgets/empty_state_widget.dart';
import 'package:servana/screens/helper_onboarding_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/services/firestore_service.dart';

class VerificationStatusScreen extends StatelessWidget {
  const VerificationStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final userStatus = userProvider.user?.verificationStatus ?? 'not_verified';
    final interviewStatus = userProvider.user?.interviewStatus;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Status'),
        automaticallyImplyLeading: false,
        actions: [
          if (userStatus == 'pending')
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildContentForStatus(context, userStatus, interviewStatus, theme),
        ),
      ),
    );
  }

  Widget _buildContentForStatus(BuildContext context, String status, String? interviewStatus, ThemeData theme) {
    final FirestoreService firestoreService = FirestoreService();

    switch (status) {
      case 'verified':
        Widget proHelperSection;

        switch (interviewStatus) {
          case 'completed':
            final score = context.read<UserProvider>().user?.interviewScore ?? 0;
            proHelperSection = EmptyStateWidget(
              icon: Icons.workspace_premium,
              title: "Congratulations! You are a Servana Pro Helper!",
              message: "You have successfully completed the interview process. Your score was $score/100.",
            );
            break;
          case 'requested':
            proHelperSection = const EmptyStateWidget(
              icon: Icons.pending_actions_rounded,
              title: "Interview Request Sent",
              message: "We've received your request. Our team will contact you shortly to schedule your interview.",
            );
            break;
          default: // 'none' or null
            proHelperSection = EmptyStateWidget(
              icon: Icons.video_call_outlined,
              title: "Become a Servana Pro!",
              message: "Take the next step. Request a video interview with our team to earn the 'Pro' badge and build more trust.",
              actionButton: ElevatedButton.icon(
                icon: const Icon(Icons.video_call_outlined),
                label: const Text('Request Interview'),
                onPressed: () async {
                  try {
                    await firestoreService.requestProInterview();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Interview request sent successfully!'), backgroundColor: Colors.green),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to send request: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
              ),
            );
        }

        return SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EmptyStateWidget(
                icon: Icons.verified_user,
                title: "You're Verified!",
                message: "You are a trusted member of the Servana community.",
                actionButton: ElevatedButton.icon(
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('Go to Helper Dashboard'),
                  onPressed: () {
                    context.read<UserProvider>().setMode(AppMode.helper);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (Route<dynamic> route) => false,
                    );
                  },
                ),
              ),
              const Divider(height: 48, thickness: 1, indent: 20, endIndent: 20),
              proHelperSection,
            ],
          ),
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
          message: "There was an issue with your previous submission. Please check your email for details and re-submit your documents.",
          actionButton: ElevatedButton.icon(
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Re-submit Documents'),
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () {
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => const HelperOnboardingScreen(),
              ));
            },
          ),
        );
      default:
        return EmptyStateWidget(
          icon: Icons.shield_outlined,
          title: "Verification Required",
          message: "There was an issue loading your status. Please restart the app.",
          actionButton: ElevatedButton(
            child: const Text('Logout'),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        );
    }
  }
}
