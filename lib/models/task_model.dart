import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String taskType;
  final String? subCategory;
  final String title;
  final String description;
  final String category;
  final GeoPoint? location;
  final String? locationAddress;
  final double budget;
  final String status;
  final double? finalAmount;
  final String paymentMethod;
  final bool isCommissionFree;
  final String posterId;
  final String posterName;
  final String? posterAvatarUrl;
  final int? posterTrustScore;
  final Timestamp? timestamp;
  final Timestamp? assignmentTimestamp;
  final String? assignedHelperId;
  final String? assignedHelperName;
  final String? assignedHelperAvatarUrl;
  final String? assignedOfferId;
  final GeoPoint? helperLastLocation;
  final String? imageUrl;
  final double? distanceKm;
  final bool isUrgent;
  final bool isFlashTask;
  final Timestamp? expiresAt;
  final String? cancellationReason;
  final String? cancelledBy;
  final List<String> participantIds; // For easier activity querying

  Task({
    required this.id,
    required this.taskType,
    required this.title,
    required this.description,
    required this.category,
    this.subCategory,
    this.location,
    this.locationAddress,
    required this.budget,
    required this.status,
    this.finalAmount,
    required this.posterId,
    required this.posterName,
    this.posterAvatarUrl,
    this.posterTrustScore,
    this.timestamp,
    this.assignmentTimestamp,
    this.assignedHelperId,
    this.assignedHelperName,
    this.assignedHelperAvatarUrl,
    this.assignedOfferId,
    this.helperLastLocation,
    this.imageUrl,
    this.distanceKm,
    this.isUrgent = false,
    this.isFlashTask = false,
    this.expiresAt,
    this.cancellationReason,
    this.cancelledBy,
    required this.paymentMethod,
    this.isCommissionFree = false,
    this.participantIds = const [],
  });

  factory Task.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};

    GeoPoint? taskLocation;
    if (data['location'] != null && data['location'] is GeoPoint) {
      taskLocation = data['location'] as GeoPoint;
    }

    return Task(
      id: snapshot.id,
      taskType: data['taskType'] as String? ?? 'physical',
      subCategory: data['subCategory'] as String?,
      title: data['title'] as String? ?? 'No Title',
      description: data['description'] as String? ?? 'No Description',
      category: data['category'] as String? ?? 'Uncategorized',
      location: taskLocation,
      locationAddress: data['locationAddress'] as String?,
      budget: (data['budget'] as num? ?? 0.0).toDouble(),
      status: data['status'] as String? ?? 'unknown',
      finalAmount: (data['finalAmount'] as num?)?.toDouble(),
      posterId: data['posterId'] as String? ?? '',
      posterName: data['posterName'] as String? ?? 'Unknown Poster',
      posterAvatarUrl: data['posterAvatarUrl'] as String?,
      posterTrustScore: (data['posterTrustScore'] as num?)?.toInt(),
      timestamp: data['timestamp'] as Timestamp?,
      assignmentTimestamp: data['assignmentTimestamp'] as Timestamp?,
      assignedHelperId: data['assignedHelperId'] as String?,
      assignedHelperName: data['assignedHelperName'] as String?,
      assignedHelperAvatarUrl: data['assignedHelperAvatarUrl'] as String?,
      assignedOfferId: data['assignedOfferId'] as String?,
      helperLastLocation: data['helperLastLocation'] as GeoPoint?,
      imageUrl: data['imageUrl'] as String?,
      distanceKm: (data['distanceKm'] as num?)?.toDouble(),
      isUrgent: data['isUrgent'] as bool? ?? false,
      isFlashTask: data['isFlashTask'] as bool? ?? false,
      expiresAt: data['expiresAt'] as Timestamp?,
      cancellationReason: data['cancellationReason'] as String?,
      cancelledBy: data['cancelledBy'] as String?,
      paymentMethod: data['paymentMethod'] as String? ?? 'escrow',
      isCommissionFree: data['isCommissionFree'] as bool? ?? false,
      participantIds: List<String>.from(data['participantIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'taskType': taskType,
      'title': title,
      'description': description,
      'category': category,
      if (subCategory != null) 'subCategory': subCategory,
      'budget': budget,
      'status': status,
      if (finalAmount != null) 'finalAmount': finalAmount,
      'posterId': posterId,
      'posterName': posterName,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      if (assignmentTimestamp != null) 'assignmentTimestamp': assignmentTimestamp,
      if (location != null) 'location': location,
      if (locationAddress != null) 'locationAddress': locationAddress,
      if (posterAvatarUrl != null) 'posterAvatarUrl': posterAvatarUrl,
      if (posterTrustScore != null) 'posterTrustScore': posterTrustScore,
      if (assignedHelperId != null) 'assignedHelperId': assignedHelperId,
      if (assignedHelperName != null) 'assignedHelperName': assignedHelperName,
      if (assignedHelperAvatarUrl != null) 'assignedHelperAvatarUrl': assignedHelperAvatarUrl,
      if (assignedOfferId != null) 'assignedOfferId': assignedOfferId,
      if (helperLastLocation != null) 'helperLastLocation': helperLastLocation,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (distanceKm != null) 'distanceKm': distanceKm,
      'isUrgent': isUrgent,
      'isFlashTask': isFlashTask,
      if (expiresAt != null) 'expiresAt': expiresAt,
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      if (cancelledBy != null) 'cancelledBy': cancelledBy,
      'paymentMethod': paymentMethod,
      'isCommissionFree': isCommissionFree,
      'participantIds': participantIds,
    };
  }
}
