import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/screens/home_screen.dart';
import 'package:servana/screens/service_selection_screen.dart';
import 'package:servana/screens/verification_status_screen.dart'; // <-- NEW IMPORT

class EditProfileScreen extends StatefulWidget {
  final bool isInitialSetup;
  final bool isHelperSetup;
  final ServiceType? serviceType;

  const EditProfileScreen({
    Key? key,
    this.isInitialSetup = false,
    this.isHelperSetup = false,
    this.serviceType,
  }) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _qualificationsController;
  late TextEditingController _experienceController;
  late TextEditingController _subjectsController;
  late TextEditingController _rateController;
  late TextEditingController _vehicleTypeController;
  late TextEditingController _vehicleDetailsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _qualificationsController = TextEditingController();
    _experienceController = TextEditingController();
    _subjectsController = TextEditingController();
    _rateController = TextEditingController();
    _vehicleTypeController = TextEditingController();
    _vehicleDetailsController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      _nameController.text = userData['displayName'] ?? user.displayName ?? '';
      _bioController.text = userData['bio'] ?? '';
      _qualificationsController.text = userData['qualifications'] ?? '';
      _experienceController.text = userData['experience'] ?? '';
      _subjectsController.text = userData['subjects'] ?? '';
      _rateController.text = (userData['hourlyRate'] ?? '').toString();
      _vehicleTypeController.text = userData['vehicleType'] ?? '';
      _vehicleDetailsController.text = userData['vehicleDetails'] ?? '';
    } catch (e) {
      print("Error loading user data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load profile data.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
      if (user.displayName != _nameController.text) {
        await user.updateDisplayName(_nameController.text);
      }

      final Map<String, dynamic> dataToSave = {
        'displayName': _nameController.text,
        'bio': _bioController.text,
        if (widget.isInitialSetup) 'hasCompletedRoleSelection': true,
      };

      if (widget.isHelperSetup) {
        switch (widget.serviceType) {
          case ServiceType.tutor:
            dataToSave.addAll({
              'qualifications': _qualificationsController.text,
              'experience': _experienceController.text,
              'subjects': _subjectsController.text,
              'hourlyRate': double.tryParse(_rateController.text) ?? 0.0,
            });
            break;
          case ServiceType.pickupDriver:
            dataToSave.addAll({
              'vehicleType': _vehicleTypeController.text,
              'vehicleDetails': _vehicleDetailsController.text,
            });
            break;
          default:
            break;
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        dataToSave,
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!'), backgroundColor: Colors.green),
        );

        // --- UPDATED NAVIGATION LOGIC ---
        if (widget.isHelperSetup) {
          // If it was helper setup, go to the status screen.
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const VerificationStatusScreen()),
                (route) => false,
          );
        } else if (widget.isInitialSetup) {
          // If it was a poster setup, go to home.
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
          );
        } else {
          // Otherwise, just pop back (it was a normal profile edit).
          Navigator.of(context).pop();
        }
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
    _vehicleTypeController.dispose();
    _vehicleDetailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isInitialSetup ? 'Set Up Profile' : 'Edit Profile'),
        automaticallyImplyLeading: !widget.isInitialSetup,
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
              if (widget.isHelperSetup)
                _buildHelperDetailsSection(),
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
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
      ),
    );
  }

  Widget _buildHelperDetailsSection() {
    List<Widget> fields = [];
    switch (widget.serviceType) {
      case ServiceType.tutor:
        fields = [
          _buildSectionHeader('Tutor Details'),
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
            decoration: const InputDecoration(labelText: 'Subjects Offered', hintText: 'e.g., Mathematics, Physics'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _rateController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Your Rate (LKR per hour)', hintText: 'e.g., 2000', prefixText: 'LKR '),
          ),
        ];
        break;
      case ServiceType.pickupDriver:
        fields = [
          _buildSectionHeader('Driver Details'),
          TextFormField(
            controller: _vehicleTypeController,
            decoration: const InputDecoration(labelText: 'Vehicle Type', hintText: 'e.g., Bike, Car, Van, Lorry'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vehicleDetailsController,
            decoration: const InputDecoration(labelText: 'Vehicle Details', hintText: 'e.g., Bajaj Pulsar 150 (2022)'),
          ),
        ];
        break;
      default:
        fields = [_buildSectionHeader('Service Details'), const Text("Please describe your service in your bio.")];
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields,
      ),
    );
  }
}
