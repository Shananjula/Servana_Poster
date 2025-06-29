import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// *** UPDATED: Importing the centralized Service model ***
import '../models/service_model.dart';

// Standalone testing code
void main() {
  runApp(const HelpifyApp());
}

class HelpifyApp extends StatelessWidget {
  const HelpifyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helpify',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Poppins',
      ),
      home: const AddEditServiceScreen(),
    );
  }
}

// --- The Add/Edit Service Screen Widget ---
class AddEditServiceScreen extends StatefulWidget {
  // If a service is passed, we are in 'edit' mode. If null, we're in 'add' mode.
  final Service? service;

  const AddEditServiceScreen({Key? key, this.service}) : super(key: key);

  @override
  State<AddEditServiceScreen> createState() => _AddEditServiceScreenState();
}

class _AddEditServiceScreenState extends State<AddEditServiceScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _rateController;
  late TextEditingController _descriptionController;

  String? _selectedCategory;
  String? _selectedRateType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.service?.title);
    _rateController = TextEditingController(text: widget.service?.rate.toStringAsFixed(0));
    _descriptionController = TextEditingController(); // Description is optional
    _selectedCategory = widget.service?.category;
    _selectedRateType = widget.service?.rateType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // *** UPDATED: Saves or updates the service in Firestore ***
  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to manage services.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Prepare data map
    final serviceData = {
      'title': _titleController.text,
      'category': _selectedCategory,
      'rate': double.tryParse(_rateController.text) ?? 0.0,
      'rateType': _selectedRateType,
      'description': _descriptionController.text,
      'helperId': user.uid,
      'helperName': user.displayName ?? 'Anonymous Helper',
      'isActive': widget.service?.isActive ?? true, // Keep old status or default to true
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    try {
      // If editing, update existing document. If adding, create a new one.
      // We'll store services in a top-level collection for easier browsing.
      if (widget.service != null) {
        // Update
        await FirebaseFirestore.instance.collection('services').doc(widget.service!.id).update(serviceData);
      } else {
        // Add
        await FirebaseFirestore.instance.collection('services').add(serviceData);
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Service ${widget.service == null ? "added" : "updated"} successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print("Failed to save service: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save service. Please try again.'), backgroundColor: Colors.red),
      );
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.service != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Service' : 'Add New Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Service Title', hintText: 'e.g., Professional Logo Design'),
                validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ['Education', 'Design', 'Handyman', 'Cleaning', 'Wellness']
                    .map((label) => DropdownMenuItem(child: Text(label), value: label))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
                validator: (value) => value == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _rateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Rate', prefixText: 'LKR '),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter rate';
                        if (double.tryParse(value) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedRateType,
                      decoration: const InputDecoration(labelText: 'Rate Type'),
                      items: ['per hour', 'per project', 'per day', 'per item']
                          .map((label) => DropdownMenuItem(child: Text(label), value: label))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedRateType = value),
                      validator: (value) => value == null ? 'Select type' : null,
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Full Description (optional)', hintText: 'Describe what your service includes...'),
                maxLines: 4,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveService,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                    : Text(isEditing ? 'Save Changes' : 'Add Service', style: const TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
