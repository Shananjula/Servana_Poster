import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/constants/service_categories.dart';

class ServiceSelectionStep extends StatefulWidget {
  final VoidCallback onContinue;
  final List<String> initialSkills;

  const ServiceSelectionStep({
    super.key,
    required this.onContinue,
    required this.initialSkills,
  });

  @override
  State<ServiceSelectionStep> createState() => _ServiceSelectionStepState();
}

class _ServiceSelectionStepState extends State<ServiceSelectionStep> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controller for the custom skill text field
  final TextEditingController _otherSkillController = TextEditingController();

  late Set<String> _selectedSkills;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSkills = Set<String>.from(widget.initialSkills);
  }

  @override
  void dispose() {
    _otherSkillController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    // Add the custom skill to the set if it's not empty
    final String customSkill = _otherSkillController.text.trim();
    if (customSkill.isNotEmpty) {
      _selectedSkills.add(customSkill);
    }

    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select or add at least one service.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'skills': _selectedSkills.toList(),
          'onboardingStep': 1,
        });
        widget.onContinue();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save services: ${e.toString()}")),
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "What services will you offer?",
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            "Select all that apply, or add your own skill below.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: AppServices.categories.keys.length + 1,
              itemBuilder: (context, index) {
                // If it's the last item, build the "Other" input field
                if (index == AppServices.categories.keys.length) {
                  return Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _otherSkillController,
                        decoration: const InputDecoration(
                          labelText: 'Other Skill',
                          hintText: 'e.g., Drone Videography',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  );
                }

                // Otherwise, build the category expansion tiles
                final category = AppServices.categories.keys.elementAt(index);
                final skills = AppServices.categories[category]!;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                    children: skills.map((skill) {
                      final isSelected = _selectedSkills.contains(skill);
                      return CheckboxListTile(
                        title: Text(skill),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedSkills.add(skill);
                            } else {
                              _selectedSkills.remove(skill);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
            onPressed: _saveAndContinue,
            child: const Text("Save & Continue"),
          ),
        ],
      ),
    );
  }
}
