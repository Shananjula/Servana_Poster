// verification_center_screen.dart (FULL UPDATED VERSION)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/screens/edit_profile_screen.dart';
import 'package:servana/screens/verification_status_screen.dart';
import 'service_selection_screen.dart';

enum DocumentType { nic, drivingLicense, selfie, qualification, cv, policeClearance, gramaNiladari, vehicleRegistration, vehicleLicense }

class VerificationCenterScreen extends StatefulWidget {
  final ServiceType serviceType;
  const VerificationCenterScreen({super.key, required this.serviceType});

  @override
  State<VerificationCenterScreen> createState() => _VerificationCenterScreenState();
}

class _VerificationCenterScreenState extends State<VerificationCenterScreen> {
  bool _isUploading = false;
  DocumentType? _currentlyUploadingType;
  final Map<DocumentType, String> _uploadedFileUrls = {};
  List<DocumentType> _mandatoryDocs = [];
  List<DocumentType> _optionalDocs = [];

  @override
  void initState() {
    super.initState();
    _setupDocumentRequirements();
  }

  void _setupDocumentRequirements() {
    _mandatoryDocs.add(DocumentType.selfie);

    switch (widget.serviceType) {
      case ServiceType.tutor:
        _mandatoryDocs.add(DocumentType.nic);
        _optionalDocs = [DocumentType.qualification, DocumentType.cv, DocumentType.policeClearance, DocumentType.gramaNiladari];
        break;
      case ServiceType.pickupDriver:
        _mandatoryDocs.addAll([DocumentType.drivingLicense, DocumentType.vehicleRegistration, DocumentType.vehicleLicense]);
        _optionalDocs = [DocumentType.policeClearance, DocumentType.gramaNiladari];
        break;
      case ServiceType.homeRepair:
      case ServiceType.other:
        _mandatoryDocs.add(DocumentType.nic);
        _optionalDocs = [DocumentType.qualification, DocumentType.policeClearance, DocumentType.gramaNiladari];
        break;
    }
  }

  Future<void> _pickAndUploadImage(DocumentType docType) async {
    setState(() {
      _isUploading = true;
      _currentlyUploadingType = docType;
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

      final fileName = '${docType.name}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('verification_documents').child(user.uid).child(fileName);

      await ref.putFile(File(image.path));
      final imageUrl = await ref.getDownloadURL();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_getDocTypeName(docType)} uploaded successfully!'), backgroundColor: Colors.green),
        );
        setState(() {
          _uploadedFileUrls[docType] = imageUrl;
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
    setState(() => _isUploading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Create the verification request document
      final requestRef = FirebaseFirestore.instance.collection('verification_requests').doc();
      batch.set(requestRef, {
        'userId': user.uid,
        'userName': user.displayName ?? 'N/A',
        'userEmail': user.email,
        'serviceType': widget.serviceType.name,
        'documents': _uploadedFileUrls.map((key, value) => MapEntry(key.name, value)),
        'status': 'pending_review',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // 2. Create or update the user's profile document
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // --- THIS IS THE FIX ---
      // Using set with merge:true is safer. It creates the document if it doesn't exist,
      // and updates it if it does, preventing errors for new users.
      batch.set(userRef, {
        'serviceType': widget.serviceType.name,
        'hasCompletedRoleSelection': true,
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const VerificationStatusScreen()),
              (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documents submitted for review!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Submission Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _getDocTypeName(DocumentType type) {
    switch (type) {
      case DocumentType.nic: return 'National ID Card';
      case DocumentType.drivingLicense: return "Driver's License";
      case DocumentType.selfie: return 'Selfie';
      case DocumentType.qualification: return 'Qualification';
      case DocumentType.cv: return 'CV / Resume';
      case DocumentType.policeClearance: return 'Police Clearance';
      case DocumentType.gramaNiladari: return 'Grama Niladari Certificate';
      case DocumentType.vehicleRegistration: return 'Vehicle Registration (CR)';
      case DocumentType.vehicleLicense: return 'Vehicle Revenue License';
    }
  }

  IconData _getDocTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.nic: return Icons.badge_outlined;
      case DocumentType.drivingLicense: return Icons.drive_eta_outlined;
      case DocumentType.selfie: return Icons.camera_alt_outlined;
      case DocumentType.qualification: return Icons.school_outlined;
      case DocumentType.cv: return Icons.description_outlined;
      case DocumentType.policeClearance: return Icons.local_police_outlined;
      case DocumentType.gramaNiladari: return Icons.location_city_outlined;
      case DocumentType.vehicleRegistration: return Icons.article_outlined;
      case DocumentType.vehicleLicense: return Icons.receipt_long_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool allMandatoryUploaded = _mandatoryDocs.every((doc) => _uploadedFileUrls.containsKey(doc)) ||
        (_mandatoryDocs.contains(DocumentType.nic) && (_uploadedFileUrls.containsKey(DocumentType.nic) || _uploadedFileUrls.containsKey(DocumentType.drivingLicense)));

    return Scaffold(
      appBar: AppBar(title: const Text('Become a Helper'), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Verify Your Identity', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('To ensure the safety of our community, please provide the following documents.', style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _buildSectionHeader(context, "Mandatory"),
            ..._mandatoryDocs.map((doc) => _buildVerificationCard(context, doc)),
            if (_optionalDocs.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionHeader(context, "Optional (Improves Trust Score)"),
              ..._optionalDocs.map((doc) => _buildVerificationCard(context, doc)),
            ],
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: allMandatoryUploaded && !_isUploading ? _submitForReview : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit for Review'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  Widget _buildVerificationCard(BuildContext context, DocumentType docType) {
    final bool isUploaded = _uploadedFileUrls.containsKey(docType);
    final bool isUploadingThis = _isUploading && _currentlyUploadingType == docType;
    final title = _getDocTypeName(docType);
    final icon = _getDocTypeIcon(docType);

    return Card(
      color: isUploaded ? Colors.teal.shade50 : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: Icon(icon, size: 40, color: Theme.of(context).primaryColor),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        trailing: isUploadingThis
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : isUploaded
            ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
            : const Icon(Icons.upload_file_rounded),
        onTap: _isUploading || isUploaded ? null : () => _pickAndUploadImage(docType),
      ),
    );
  }
}
