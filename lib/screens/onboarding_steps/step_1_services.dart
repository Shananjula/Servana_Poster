import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  late Set<String> _selectedSkills;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSkills = Set<String>.from(widget.initialSkills);
  }

  Future<void> _saveAndContinue() async {
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one service.")),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save services: ${e.toString()}")),
      );
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
            "Select all that apply. This helps customers find you.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('services').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No services found. Please contact support."));
                }
                final services = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    final serviceName = service['name'] as String? ?? 'Unnamed Service';
                    final isSelected = _selectedSkills.contains(serviceName);

                    return Card(
                      color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : null,
                      child: CheckboxListTile(
                        title: Text(serviceName),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedSkills.add(serviceName);
                            } else {
                              _selectedSkills.remove(serviceName);
                            }
                          });
                        },
                      ),
                    );
                  },
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
