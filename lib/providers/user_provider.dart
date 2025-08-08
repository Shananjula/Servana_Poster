import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servana/models/user_model.dart';
import 'dart:async';

// Enum to define the app's active mode
enum AppMode { poster, helper }

/// A provider class to manage the state of the currently logged-in user.
class UserProvider with ChangeNotifier {
  HelpifyUser? _user;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // State for the active mode
  AppMode _activeMode = AppMode.poster;

  HelpifyUser? get user => _user;
  AppMode get activeMode => _activeMode; // Getter for the active mode
  bool get isVerifiedHelper =>
      _user?.isHelper == true && _user?.verificationStatus == 'verified';

  /// Sets the initial Firebase user and starts listening for real-time updates.
  void setUser(User firebaseUser) {
    // Avoid re-subscribing if the user is already being listened to.
    if (_user?.id == firebaseUser.uid) return;

    _userSubscription?.cancel();

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        // --- ⭐️ FIX: Check if this is the first time loading the user ---
        final bool isInitialLoad = _user == null;

        // Always update the user data with the latest from Firestore
        _user = HelpifyUser.fromFirestore(snapshot);

        // --- ⭐️ FIX: Only set the default mode on the initial load ---
        // This prevents the mode from toggling when other user data (like
        // servCoinBalance) changes. The mode will now only change when the
        // user explicitly switches it.
        if (isInitialLoad) {
          if (_user?.isHelper == true) {
            // Default to helper mode only if they are verified.
            if (_user?.verificationStatus == 'verified') {
              _activeMode = AppMode.helper;
            } else {
              _activeMode = AppMode.poster;
            }
          } else {
            _activeMode = AppMode.poster;
          }
        }

        notifyListeners();
      }
    }, onError: (error) {
      print("Error listening to user document: $error");
      clearUser();
    });
  }

  /// --- NEW: Method to explicitly set the active mode ---
  /// This is used after verification to force the UI into helper mode.
  void setMode(AppMode newMode) {
    if (_activeMode != newMode) {
      _activeMode = newMode;
      notifyListeners();
    }
  }

  /// Method to toggle the active mode
  void switchMode() {
    // This method can only be triggered by a registered helper.
    // It toggles between their two available views.
    if (_activeMode == AppMode.helper) {
      _activeMode = AppMode.poster;
    } else {
      _activeMode = AppMode.helper;
    }
    notifyListeners();
  }

  /// Clears user data on logout.
  void clearUser() {
    _userSubscription?.cancel();
    _user = null;
    _activeMode = AppMode.poster; // Reset to default on logout
    notifyListeners();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
