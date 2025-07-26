import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:servana/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/screens/onboarding_steps/step_1_services.dart';
import 'package:servana/screens/onboarding_steps/step_2_documents.dart';
import 'package:servana/screens/onboarding_steps/step_3_review.dart';


class HelperOnboardingScreen extends StatefulWidget {
  const HelperOnboardingScreen({super.key});

  @override
  State<HelperOnboardingScreen> createState() => _HelperOnboardingScreenState();
}

class _HelperOnboardingScreenState extends State<HelperOnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Start the user on the step they last left off on
    _currentPage = context.read<UserProvider>().user?.onboardingStep ?? 0;
    _pageController = PageController(initialPage: _currentPage);

    // Listen to page changes to update the progress bar
    _pageController.addListener(() {
      if (_pageController.page?.round() != _currentPage) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final totalSteps = 3;
    final currentProgress = (user?.onboardingStep ?? 0) / totalSteps;

    // This list defines your entire onboarding flow.
    final List<Widget> onboardingSteps = [
      ServiceSelectionStep(
        onContinue: _goToNextPage,
        initialSkills: user?.skills ?? [],
      ),
      DocumentUploadStep(
        onContinue: _goToNextPage,
      ),
      const ReviewSubmitStep(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Become a Helper"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: 'Logout',
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10.0),
          child: LinearPercentIndicator(
            percent: currentProgress,
            lineHeight: 5.0,
            backgroundColor: Colors.grey[300],
            progressColor: Theme.of(context).colorScheme.primary,
            animateFromLastPercent: true,
            animation: true,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        // We disable manual swiping. Navigation is handled by the "Continue" buttons.
        physics: const NeverScrollableScrollPhysics(),
        children: onboardingSteps,
      ),
    );
  }
}
