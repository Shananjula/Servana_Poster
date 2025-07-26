import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// This service class encapsulates all the logic for picking and uploading files.
// This keeps your UI widgets clean and focused on presentation.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generic method to pick an image from gallery or camera
  Future<File?> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  // Uploads a file and updates the corresponding field in the user's Firestore document.
  Future<String?> uploadFileAndUpdateUser({
    required File file,
    required String documentType, // e.g., 'nicFrontUrl', 'policeClearanceUrl'
    required BuildContext context,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to upload files.")),
      );
      return null;
    }

    try {
      // Create a reference in Firebase Storage
      final ref = _storage.ref('user_documents/${user.uid}/$documentType.jpg');

      // Upload the file
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() => {});

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update the user's document in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        documentType: downloadUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$documentType uploaded successfully!")),
      );
      return downloadUrl;

    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload file: ${e.message}")),
      );
      return null;
    }
  }
}
