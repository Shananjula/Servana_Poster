import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String taskType;
  final String title;
  final String description;
  final String category;
  final String? subCategory;
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
  final String? assignedHelperId;
  final String? assignedHelperName;
  final String? assignedHelperAvatarUrl;
  final List<String> participantIds;

  // --- Fields for reciprocal contact info ---
  final String? posterPhoneNumber;
  final String? assignedHelperPhoneNumber;

  // --- All other existing fields ---
  final String? assignedOfferId;
  final GeoPoint? helperLastLocation;
  final String? imageUrl;
  final Timestamp? timestamp;
  final Timestamp? assignmentTimestamp;
  final Timestamp? expiresAt;
  final Timestamp? helperStartedJourneyAt;
  final Timestamp? helperArrivedAt;
  final Timestamp? posterConfirmedStartAt;
  final Timestamp? helperCompletedAt;
  final Timestamp? posterConfirmedCompletionAt;
  final Timestamp? paymentCompletedAt;
  final Timestamp? ratedAt;
  final String? confirmationCode;
  final String? proofImageUrl;
  final String? cancellationReason;
  final String? cancelledBy;
  final String? disputeReason;
  final String? disputeInitiatorId;
  final Timestamp? disputeTimestamp;


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
    this.assignedHelperId,
    this.assignedHelperName,
    this.assignedHelperAvatarUrl,
    this.participantIds = const [],
    // --- Added to constructor ---
    this.posterPhoneNumber,
    this.assignedHelperPhoneNumber,
    // --- All other fields ---
    this.assignedOfferId,
    this.helperLastLocation,
    this.imageUrl,
    this.timestamp,
    this.assignmentTimestamp,
    this.expiresAt,
    this.helperStartedJourneyAt,
    this.helperArrivedAt,
    this.posterConfirmedStartAt,
    this.helperCompletedAt,
    this.posterConfirmedCompletionAt,
    this.paymentCompletedAt,
    this.ratedAt,
    this.confirmationCode,
    this.proofImageUrl,
    this.cancellationReason,
    this.cancelledBy,
    this.disputeReason,
    this.disputeInitiatorId,
    this.disputeTimestamp,
    required this.paymentMethod,
    required this.isCommissionFree,
  });

  factory Task.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return Task(
      id: snapshot.id,
      taskType: data['taskType'] as String? ?? 'physical',
      title: data['title'] as String? ?? 'No Title',
      description: data['description'] as String? ?? 'No Description',
      category: data['category'] as String? ?? 'Uncategorized',
      subCategory: data['subCategory'] as String?,
      location: data['location'] as GeoPoint?,
      locationAddress: data['locationAddress'] as String?,
      budget: (data['budget'] as num? ?? 0.0).toDouble(),
      status: data['status'] as String? ?? 'unknown',
      finalAmount: (data['finalAmount'] as num?)?.toDouble(),
      posterId: data['posterId'] as String? ?? '',
      posterName: data['posterName'] as String? ?? 'Unknown Poster',
      posterAvatarUrl: data['posterAvatarUrl'] as String?,
      posterTrustScore: (data['posterTrustScore'] as num?)?.toInt(),
      assignedHelperId: data['assignedHelperId'] as String?,
      assignedHelperName: data['assignedHelperName'] as String?,
      assignedHelperAvatarUrl: data['assignedHelperAvatarUrl'] as String?,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      paymentMethod: data['paymentMethod'] as String? ?? 'escrow',
      isCommissionFree: data['isCommissionFree'] as bool? ?? false,

      // Reading phone numbers from Firestore
      posterPhoneNumber: data['posterPhoneNumber'] as String?,
      assignedHelperPhoneNumber: data['assignedHelperPhoneNumber'] as String?,

      // All other fields
      assignedOfferId: data['assignedOfferId'] as String?,
      helperLastLocation: data['helperLastLocation'] as GeoPoint?,
      imageUrl: data['imageUrl'] as String?,
      timestamp: data['timestamp'] as Timestamp?,
      assignmentTimestamp: data['assignmentTimestamp'] as Timestamp?,
      expiresAt: data['expiresAt'] as Timestamp?,
      helperStartedJourneyAt: data['helperStartedJourneyAt'] as Timestamp?,
      helperArrivedAt: data['helperArrivedAt'] as Timestamp?,
      posterConfirmedStartAt: data['posterConfirmedStartAt'] as Timestamp?,
      helperCompletedAt: data['helperCompletedAt'] as Timestamp?,
      posterConfirmedCompletionAt: data['posterConfirmedCompletionAt'] as Timestamp?,
      paymentCompletedAt: data['paymentCompletedAt'] as Timestamp?,
      ratedAt: data['ratedAt'] as Timestamp?,
      confirmationCode: data['confirmationCode'] as String?,
      proofImageUrl: data['proofImageUrl'] as String?,
      cancellationReason: data['cancellationReason'] as String?,
      cancelledBy: data['cancelledBy'] as String?,
      disputeReason: data['disputeReason'] as String?,
      disputeInitiatorId: data['disputeInitiatorId'] as String?,
      disputeTimestamp: data['disputeTimestamp'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'taskType': taskType,
      'title': title,
      'description': description,
      'category': category,
      'subCategory': subCategory,
      'location': location,
      'locationAddress': locationAddress,
      'budget': budget,
      'status': status,
      'finalAmount': finalAmount,
      'paymentMethod': paymentMethod,
      'isCommissionFree': isCommissionFree,
      'posterId': posterId,
      'posterName': posterName,
      'posterAvatarUrl': posterAvatarUrl,
      'posterTrustScore': posterTrustScore,
      'timestamp': timestamp,
      'assignmentTimestamp': assignmentTimestamp,
      'assignedHelperId': assignedHelperId,
      'assignedHelperName': assignedHelperName,
      'assignedHelperAvatarUrl': assignedHelperAvatarUrl,
      'assignedOfferId': assignedOfferId,
      'helperLastLocation': helperLastLocation,
      'imageUrl': imageUrl,
      'expiresAt': expiresAt,
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
      'participantIds': participantIds,
      'helperStartedJourneyAt': helperStartedJourneyAt,
      'helperArrivedAt': helperArrivedAt,
      'posterConfirmedStartAt': posterConfirmedStartAt,
      'helperCompletedAt': helperCompletedAt,
      'posterConfirmedCompletionAt': posterConfirmedCompletionAt,
      'paymentCompletedAt': paymentCompletedAt,
      'ratedAt': ratedAt,
      'confirmationCode': confirmationCode,
      'proofImageUrl': proofImageUrl,
      'disputeReason': disputeReason,
      'disputeInitiatorId': disputeInitiatorId,
      'disputeTimestamp': disputeTimestamp,
      // --- Writing new fields to Firestore ---
      'posterPhoneNumber': posterPhoneNumber,
      'assignedHelperPhoneNumber': assignedHelperPhoneNumber,
    };
  }
}
