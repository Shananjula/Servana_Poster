import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- Edit Profile Screen Widget ---
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers for all form fields
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _qualificationsController;
  late TextEditingController _experienceController;
  late TextEditingController _subjectsController;
  late TextEditingController _rateController;

  bool _isHelper = false; // To toggle the Helper Details section

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Load existing user data from Firestore
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    // Initialize controllers with Firestore data
    _nameController = TextEditingController(text: userData['displayName'] ?? user.displayName);
    _bioController = TextEditingController(text: userData['bio'] ?? '');
    _qualificationsController = TextEditingController(text: userData['qualifications'] ?? '');
    _experienceController = TextEditingController(text: userData['experience'] ?? '');
    _subjectsController = TextEditingController(text: userData['subjects'] ?? '');
    _rateController = TextEditingController(text: (userData['hourlyRate'] ?? 0).toString());
    _isHelper = userData['isHelper'] ?? false;

    setState(() => _isLoading = false);
  }

  // Save updated data back to Firestore
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    try {
      // Update Auth profile if name changed
      if (user.displayName != _nameController.text) {
        await user.updateDisplayName(_nameController.text);
      }

      // Prepare data map
      final Map<String, dynamic> dataToSave = {
        'displayName': _nameController.text,
        'bio': _bioController.text,
        'isHelper': _isHelper,
        if (_isHelper) ...{
          'qualifications': _qualificationsController.text,
          'experience': _experienceController.text,
          'subjects': _subjectsController.text,
          'hourlyRate': double.tryParse(_rateController.text) ?? 0.0,
        }
      };

      // Update the user's document in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        dataToSave,
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }

    } catch(e) {
      print("Error saving profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _qualificationsController.dispose();
    _experienceController.dispose();
    _subjectsController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            icon: _isSaving ? const SizedBox(width:20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0,)) : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveProfile,
            tooltip: 'Save Profile',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Personal Information'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Your Bio', hintText: 'A short introduction about yourself...'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // --- Helper Details Section ---
              SwitchListTile(
                title: const Text('I am a Helper/Tutor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: const Text('Enable this to offer your services.'),
                value: _isHelper,
                onChanged: (value) => setState(() => _isHelper = value),
                activeColor: Theme.of(context).primaryColor,
              ),

              // Animated visibility for helper-specific fields
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _isHelper
                    ? _buildHelperDetailsSection()
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
      ),
    );
  }

  Widget _buildHelperDetailsSection() {
    return Container(
      margin: const EdgeInsets.only(top: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Helper Details'),
          TextFormField(
            controller: _qualificationsController,
            decoration: const InputDecoration(labelText: 'Educational Qualifications', hintText: 'e.g., B.Sc. in Computer Science'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _experienceController,
            decoration: const InputDecoration(labelText: 'Teaching/Work Experience', hintText: 'e.g., 5 years as a private tutor'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _subjectsController,
            decoration: const InputDecoration(labelText: 'Subjects or Skills Offered', hintText: 'e.g., Mathematics, Physics, Graphic Design'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _rateController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Your Rate (LKR)', hintText: 'e.g., 2000', prefixText: 'LKR '),
          ),
        ],
      ),
    );
  }
}
