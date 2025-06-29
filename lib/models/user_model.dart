import 'package:cloud_firestore/cloud_firestore.dart';

class HelpifyUser {
  final String id;
  final String? displayName;
  final String? email;
  final String? photoURL;
  final String? phoneNumber;
  final String? bio;
  final bool? isHelper;

  // Helper-specific fields
  final String? qualifications;
  final String? experience;
  final List<String> skills; // MODIFIED: Changed from String? to List<String> for skill tags
  final List<String> badges; // NEW: For "Skill Quest" badges
  final double? hourlyRate;
  final int? trustScore;
  final int cancellationCount;

  // User ratings
  final int ratingCount;
  final double averageRating;

  // Promotional & Growth Fields
  final int commissionFreeTasksPosted;
  final int commissionFreeTasksCompleted;
  final int bonusTasksAvailable;

  // Wallet & Credit System Fields
  final double coinWalletBalance;
  final double creditCoinBalance;
  final bool initialCreditGranted;

  // Verification
  final String verificationStatus;

  // NEW: Profile Completion Score (calculated)
  final double profileCompletion;

  HelpifyUser({
    required this.id,
    this.displayName,
    this.email,
    this.photoURL,
    this.phoneNumber,
    this.bio,
    this.isHelper,
    this.qualifications,
    this.experience,
    this.skills = const [], // MODIFIED: Default to empty list
    this.badges = const [], // NEW: Default to empty list
    this.hourlyRate,
    this.trustScore,
    this.cancellationCount = 0,
    this.ratingCount = 0,
    this.averageRating = 0.0,
    this.commissionFreeTasksPosted = 0,
    this.commissionFreeTasksCompleted = 0,
    this.bonusTasksAvailable = 0,
    this.coinWalletBalance = 0.0,
    this.creditCoinBalance = 0.0,
    this.initialCreditGranted = false,
    this.verificationStatus = 'not_verified',
  }) : profileCompletion = _calculateProfileCompletion(
    displayName: displayName,
    photoURL: photoURL,
    phoneNumber: phoneNumber,
    bio: bio,
    isHelper: isHelper,
    qualifications: qualifications,
    experience: experience,
    skills: skills,
  );


  factory HelpifyUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Missing data for userId: ${snapshot.id}');
    }
    return HelpifyUser(
      id: snapshot.id,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      photoURL: data['photoURL'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      bio: data['bio'] as String?,
      isHelper: data['isHelper'] as bool?,
      qualifications: data['qualifications'] as String?,
      experience: data['experience'] as String?,
      skills: List<String>.from(data['skills'] ?? []), // MODIFIED: Read list
      badges: List<String>.from(data['badges'] ?? []), // NEW: Read list
      hourlyRate: (data['hourlyRate'] as num?)?.toDouble(),
      trustScore: (data['trustScore'] as num?)?.toInt(),
      cancellationCount: data['cancellationCount'] as int? ?? 0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
      commissionFreeTasksPosted: (data['commissionFreeTasksPosted'] as num?)?.toInt() ?? 0,
      commissionFreeTasksCompleted: (data['commissionFreeTasksCompleted'] as num?)?.toInt() ?? 0,
      bonusTasksAvailable: (data['bonusTasksAvailable'] as num?)?.toInt() ?? 0,
      coinWalletBalance: (data['coinWalletBalance'] as num?)?.toDouble() ?? 0.0,
      creditCoinBalance: (data['creditCoinBalance'] as num?)?.toDouble() ?? 0.0,
      initialCreditGranted: data['initialCreditGranted'] as bool? ?? false,
      verificationStatus: data['verificationStatus'] as String? ?? 'not_verified',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'phoneNumber': phoneNumber,
      'bio': bio,
      'isHelper': isHelper,
      'qualifications': qualifications,
      'experience': experience,
      'skills': skills,
      'badges': badges,
      'hourlyRate': hourlyRate,
      'trustScore': trustScore,
      'cancellationCount': cancellationCount,
      'ratingCount': ratingCount,
      'averageRating': averageRating,
      'commissionFreeTasksPosted': commissionFreeTasksPosted,
      'commissionFreeTasksCompleted': commissionFreeTasksCompleted,
      'bonusTasksAvailable': bonusTasksAvailable,
      'coinWalletBalance': coinWalletBalance,
      'creditCoinBalance': creditCoinBalance,
      'initialCreditGranted': initialCreditGranted,
      'verificationStatus': verificationStatus,
    };
  }

  // --- NEW: Profile Completion Logic ---
  static double _calculateProfileCompletion({
    String? displayName,
    String? photoURL,
    String? phoneNumber,
    String? bio,
    bool? isHelper,
    String? qualifications,
    String? experience,
    List<String>? skills,
  }) {
    int score = 0;
    int maxScore = 4; // Max score for non-helpers

    if (displayName != null && displayName.isNotEmpty) score++;
    if (photoURL != null && photoURL.isNotEmpty) score++;
    if (phoneNumber != null && phoneNumber.isNotEmpty) score++;
    if (bio != null && bio.isNotEmpty) score++;

    if (isHelper == true) {
      maxScore = 7; // Max score for helpers
      if (qualifications != null && qualifications.isNotEmpty) score++;
      if (experience != null && experience.isNotEmpty) score++;
      if (skills != null && skills.isNotEmpty) score++;
    }

    return score / maxScore;
  }
}
