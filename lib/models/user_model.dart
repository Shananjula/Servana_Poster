import 'package:cloud_firestore/cloud_firestore.dart';

/// --- NEW ---
/// Enum for tiered verification to provide a structured and clear status.
enum VerificationTier { none, bronze, silver, gold }

class HelpifyUser {
  final String id;
  final String? displayName;
  final String? email;
  final String? photoURL;
  final String? phoneNumber;
  final String? bio;
  final bool? isHelper;
  final bool isLive; // For "Task Radio" feature

  // --- UPDATED: Helper-specific fields ---
  final String? qualifications;
  final String? experience;
  final List<String> skills;
  final List<String> badges;
  final double? hourlyRate;
  final int trustScore;

  // --- NEW: For helper map view and service areas ---
  final GeoPoint? workLocation;
  final String? workLocationAddress;

  // User ratings and task history
  final int ratingCount;
  final double averageRating;
  final int cancellationCount;
  final int commissionFreeTasksPosted;
  final int commissionFreeTasksCompleted;
  final int bonusTasksAvailable;

  // --- NEW: Monetization & Subscription ---
  final bool isProMember;
  final Timestamp? proMembershipExpiry;

  // Wallet & Credit System Fields
  final double coinWalletBalance;
  final double creditCoinBalance;
  final bool initialCreditGranted;

  // --- UPDATED: Verification System ---
  final String verificationStatus; // e.g., 'not_verified', 'pending', 'rejected', 'verified'
  final VerificationTier verificationTier;

  // Calculated property for profile completion
  final double profileCompletion;

  HelpifyUser({
    required this.id,
    this.displayName,
    this.email,
    this.photoURL,
    this.phoneNumber,
    this.bio,
    this.isHelper,
    this.isLive = false,
    this.qualifications,
    this.experience,
    this.skills = const [],
    this.badges = const [],
    this.hourlyRate,
    this.trustScore = 10,
    this.cancellationCount = 0,
    this.workLocation,
    this.workLocationAddress,
    this.ratingCount = 0,
    this.averageRating = 0.0,
    this.isProMember = false,
    this.proMembershipExpiry,
    this.commissionFreeTasksPosted = 0,
    this.commissionFreeTasksCompleted = 0,
    this.bonusTasksAvailable = 0,
    this.coinWalletBalance = 0.0,
    this.creditCoinBalance = 0.0,
    this.initialCreditGranted = false,
    this.verificationStatus = 'not_verified',
    this.verificationTier = VerificationTier.none,
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
      isLive: data['isLive'] as bool? ?? false,
      qualifications: data['qualifications'] as String?,
      experience: data['experience'] as String?,
      skills: List<String>.from(data['skills'] ?? []),
      badges: List<String>.from(data['badges'] ?? []),
      hourlyRate: (data['hourlyRate'] as num?)?.toDouble(),
      trustScore: (data['trustScore'] as num?)?.toInt() ?? 10,
      cancellationCount: data['cancellationCount'] as int? ?? 0,
      workLocation: data['workLocation'] as GeoPoint?,
      workLocationAddress: data['workLocationAddress'] as String?,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
      isProMember: data['isProMember'] as bool? ?? false,
      proMembershipExpiry: data['proMembershipExpiry'] as Timestamp?,
      commissionFreeTasksPosted: (data['commissionFreeTasksPosted'] as num?)?.toInt() ?? 0,
      commissionFreeTasksCompleted: (data['commissionFreeTasksCompleted'] as num?)?.toInt() ?? 0,
      bonusTasksAvailable: (data['bonusTasksAvailable'] as num?)?.toInt() ?? 0,
      coinWalletBalance: (data['coinWalletBalance'] as num?)?.toDouble() ?? 0.0,
      creditCoinBalance: (data['creditCoinBalance'] as num?)?.toDouble() ?? 0.0,
      initialCreditGranted: data['initialCreditGranted'] as bool? ?? false,
      verificationStatus: data['verificationStatus'] as String? ?? 'not_verified',
      verificationTier: VerificationTier.values.firstWhere(
            (e) => e.name == data['verificationTier'],
        orElse: () => VerificationTier.none,
      ),
    );
  }

  static double _calculateProfileCompletion({
    String? displayName, String? photoURL, String? phoneNumber, String? bio,
    bool? isHelper, String? qualifications, String? experience, List<String>? skills,
  }) {
    int score = 0;
    int maxScore = 4;
    if (displayName != null && displayName.isNotEmpty) score++;
    if (photoURL != null && photoURL.isNotEmpty) score++;
    if (phoneNumber != null && phoneNumber.isNotEmpty) score++;
    if (bio != null && bio.isNotEmpty) score++;
    if (isHelper == true) {
      maxScore = 7;
      if (qualifications != null && qualifications.isNotEmpty) score++;
      if (experience != null && experience.isNotEmpty) score++;
      if (skills != null && skills.isNotEmpty) score++;
    }
    if (maxScore == 0) return 0.0;
    return score / maxScore;
  }
}
