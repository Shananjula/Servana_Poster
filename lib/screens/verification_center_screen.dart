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

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchExistingRequests();
  }

  Future<void> _fetchExistingRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final requestsSnapshot = await FirebaseFirestore.instance
        .collection('verification_requests')
        .where('userId', isEqualTo: user.uid)
        .get();

    if (mounted) {
      setState(() {
        for (var doc in requestsSnapshot.docs) {
          final data = doc.data();
          final type = data['documentType'] as String?;
          if (type != null) {
            _uploadedDocTypes.add(type);
          }
        }
      });
    }
  }

  Future<void> _pickAndUploadImage(String type) async {
    setState(() {
      _isUploading = true;
      _currentlyUploadingType = type;
    });

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image == null) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _currentlyUploadingType = null;
        });
      }
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final fileName = '${user.uid}_${type}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('verification_documents').child(fileName);

      await ref.putFile(File(image.path));
      final imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('verification_requests').add({
        'userId': user.uid,
        'userName': user.displayName ?? 'N/A',
        'userEmail': user.email,
        'documentType': type,
        'documentUrl': imageUrl,
        'status': 'pending_upload',
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
    setState(() => _isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'verificationStatus': 'pending',
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Submitted for Review"),
            content: const Text("Your documents are now pending review. We'll notify you once it's complete."),
            actions: [
              TextButton(
                child: const Text("OK"),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = _uploadedDocTypes.contains('NIC') || _uploadedDocTypes.contains('DrivingLicense');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Hub'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.shield_outlined, size: 80, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'Become a Trusted Member',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Uploading documents helps build trust. Verified members get a badge and access to more tasks.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            Text(
              'Please upload AT LEAST ONE of the following:',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            _buildVerificationCard(
              context: context,
              docType: 'NIC',
              title: 'National ID Card (NIC)',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 16),
            _buildVerificationCard(
              context: context,
              docType: 'DrivingLicense',
              title: "Driver's License",
              icon: Icons.drive_eta_outlined,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Optional Documents Section - FIXED stray character
            Text(
              'Optional Documents (to increase Trust Score)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            _buildVerificationCard(
              context: context,
              docType: 'PoliceReport',
              title: 'Police Clarification',
              subtitle: 'Optional',
              icon: Icons.local_police_outlined,
            ),
            const SizedBox(height: 16),
            _buildVerificationCard(
              context: context,
              docType: 'GramaNiladariCert',
              title: 'Grama Niladari Certificate',
              subtitle: 'Optional',
              icon: Icons.home_work_outlined,
            ),
            const SizedBox(height: 40),

            if (_isSubmitting)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: canSubmit ? _submitForReview : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: Text(canSubmit ? 'Submit for Review' : 'Upload NIC or License'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard({
    required BuildContext context,
    required String docType,
    required String title,
    required IconData icon,
    String? subtitle,
  }) {
    final bool isUploaded = _uploadedDocTypes.contains(docType);
    final bool isUploadingThis = _isUploading && _currentlyUploadingType == docType;

    return Opacity(
      opacity: _isUploading && !isUploadingThis ? 0.5 : 1.0,
      child: Card(
        elevation: 2,
        color: isUploaded ? Colors.teal.shade50 : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isUploaded ? BorderSide(color: Colors.teal.shade200, width: 1.5) : BorderSide.none,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          leading: Icon(icon, size: 40, color: Theme.of(context).primaryColor),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: subtitle != null ? Text(subtitle) : null,
          trailing: isUploadingThis
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator())
              : isUploaded
              ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
              : const Icon(Icons.arrow_forward_ios_rounded),
          onTap: _isUploading || isUploaded ? null : () => _pickAndUploadImage(docType),
        ),
      ),
    );
  }
}
