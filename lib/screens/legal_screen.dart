// lib/screens/legal_screen.dart
import 'package:flutter/material.dart';
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, this.title = 'Legal & Privacy'});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text('Your terms and privacy content here...'),
        ),
      ),
    );
  }
}
