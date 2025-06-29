import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'dart:async';

/// A provider class to manage the state of the currently logged-in user.
///
/// This uses the ChangeNotifier pattern to notify listeners when the user's
/// data changes, allowing the UI to reactively update without needing to
/// re-fetch data from Firestore constantly.
class UserProvider with ChangeNotifier {
  HelpifyUser? _user;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  HelpifyUser? get user => _user;
  bool get isVerifiedHelper => _user?.isHelper == true && _user?.verificationStatus == 'verified';

  /// Sets the initial Firebase user and starts listening for real-time updates.
  void setUser(User firebaseUser) {
    // If we are already listening for this user, do nothing.
    if (_user?.id == firebaseUser.uid) return;

    // Cancel any previous subscription
    _userSubscription?.cancel();

    // Start a new subscription to the user's document in Firestore
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _user = HelpifyUser.fromFirestore(snapshot);
        // Notify all listening widgets that the user data has been updated.
        notifyListeners();
      }
    }, onError: (error) {
      print("Error listening to user document: $error");
      // Handle error case, maybe clear the user
      clearUser();
    });
  }

  /// Clears user data on logout.
  void clearUser() {
    _userSubscription?.cancel();
    _user = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
