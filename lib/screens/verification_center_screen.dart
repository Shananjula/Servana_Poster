// lib/screens/verification_center_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerificationCenterScreen extends StatefulWidget {
  const VerificationCenterScreen({super.key});

  @override
  State<VerificationCenterScreen> createState() => _VerificationCenterScreenState();
}

class _VerificationCenterScreenState extends State<VerificationCenterScreen> {
  bool _isUploading = false;
  String? _currentlyUploadingType;
  final Set<String> _uploadedDocTypes = {};

  Future<void> _pickAndUploadImage(String type) async {
    setState(() {
      _isUploading = true;
      _currentlyUploadingType = type;
    });

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image == null) {
      if (mounted) setState(() { _isUploading = false; _currentlyUploadingType = null; });
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final fileName = '${type}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('verification_documents')
          .child(user.uid)
          .child(fileName);

      await ref.putFile(File(image.path));
      final imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('verification_requests').add({
        'userId': user.uid,
        'userName': user.displayName ?? 'N/A',
        'userEmail': user.email,
        'documentType': type,
        'documentUrl': imageUrl,
        'status': 'pending_review',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$type uploaded successfully!'), backgroundColor: Colors.green),
        );
        setState(() {
          _uploadedDocTypes.add(type);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _currentlyUploadingType = null;
        });
      }
    }
  }

  Future<void> _submitForReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'verificationStatus': 'pending',
    });

    if (mounted) {
      Navigator.of(context).pop();
    }
  }


  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _uploadedDocTypes.contains('NIC') || _uploadedDocTypes.contains('DrivingLicense');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Documents'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Please upload a clear image of your NIC or Driver\'s License.',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildVerificationCard(context, 'NIC', 'National ID Card (NIC)', Icons.badge_outlined),
            const SizedBox(height: 16),
            _buildVerificationCard(context, "DrivingLicense", "Driver's License", Icons.drive_eta_outlined),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: canSubmit ? _submitForReview : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: const Text('Submit for Review'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard(BuildContext context, String docType, String title, IconData icon) {
    final bool isUploaded = _uploadedDocTypes.contains(docType);
    final bool isUploadingThis = _isUploading && _currentlyUploadingType == docType;

    return Card(
      color: isUploaded ? Colors.teal.shade50 : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        leading: Icon(icon, size: 40, color: Theme.of(context).primaryColor),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        trailing: isUploadingThis
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator())
            : isUploaded
            ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
            : const Icon(Icons.arrow_forward_ios_rounded),
        onTap: _isUploading || isUploaded ? null : () => _pickAndUploadImage(docType),
      ),
    );
  }
}