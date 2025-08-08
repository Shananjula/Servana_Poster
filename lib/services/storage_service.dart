import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Picks an image from the user's gallery.
  /// Returns a File object or null if the user cancels.
  Future<File?> pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print("Error picking image: $e");
      return null;
    }
  }

  /// Uploads a file to the correct user-specific path in Firebase Storage
  /// and then updates the corresponding field in the user's Firestore document.
  Future<String?> uploadFileAndUpdateUser({
    required File file,
    required String documentType, // e.g., "nicFrontUrl"
    required BuildContext context, // For showing SnackBars
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: You must be logged in to upload files.")),
      );
      return null;
    }

    try {
      // --- THIS IS THE CRITICAL PART ---
      // We construct a unique, secure path for each user's document.
      // This path matches the new Firebase Storage security rules.
      final String fileName = '${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = 'user_documents/${user.uid}/$fileName';

      // 1. Create a reference to the path and upload the file
      final ref = _storage.ref().child(filePath);
      final uploadTask = ref.putFile(file);

      // 2. Wait for the upload to complete
      final snapshot = await uploadTask.whenComplete(() => {});

      // 3. Get the public download URL for the file
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // 4. Update the user's document in Firestore with the new URL
      await _firestore.collection('users').doc(user.uid).update({
        documentType: downloadUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$documentType uploaded successfully!")),
      );

      return downloadUrl;

    } on FirebaseException catch (e) {
      // Handle potential errors, like permission denied
      print("Error during file upload: ${e.code} - ${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: ${e.message}")),
      );
      return null;
    }
  }
}
