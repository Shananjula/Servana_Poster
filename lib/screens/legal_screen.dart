import 'package:flutter/material.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String contentKey;

  const LegalScreen({
    super.key,
    required this.title,
    required this.contentKey,
  });

  static const Map<String, String> _content = {
    'about': """
**Our Mission**

Welcome to Helpify, the premier AI-powered task marketplace designed for Sri Lanka. Our mission is simple: to connect people who need help with everyday tasks to a trusted community of local service providers and skilled helpers, quickly and efficiently.

We are more than just a marketplace; we are a community built on trust, reliability, and the Sri Lankan spirit of helping one another.
""",
    'terms': """
**Last Updated:** June 27, 2025

**1. Acceptance of Terms**
By creating an account and using our Service, you agree to be bound by these Terms.

**2. The Service**
Helpify is a platform that connects users who wish to outsource tasks ("Posters") with users who wish to perform those tasks ("Helpers"). We are a neutral venue.

**3. User Accounts**
You must be at least 18 years old. You are responsible for your account's security. To operate as a Helper, you must complete our verification process.
""",
    'privacy': """
**Last Updated:** June 27, 2025

**1. Information We Collect**
- Information You Provide: Name, contact details, profile info, verification documents.
- Location Information: To show nearby tasks.
- Transaction & Usage Information.

**2. How We Use Your Information**
To provide our service, facilitate connections, verify identity, process payments, and send notifications.

**3. How We Share Your Information**
Between users to facilitate a task and for legal reasons if required.
""",
  };

  @override
  Widget build(BuildContext context) {
    List<TextSpan> formatText(String text) {
      final List<TextSpan> spans = [];
      final RegExp regExp = RegExp(r'\*\*(.*?)\*\*');
      text.splitMapJoin(
        regExp,
        onMatch: (m) {
          spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.bold)));
          return '';
        },
        onNonMatch: (n) {
          spans.add(TextSpan(text: n));
          return '';
        },
      );
      return spans;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
            children: formatText(_content[contentKey] ?? 'Content not found.'),
          ),
        ),
      ),
    );
  }
}
