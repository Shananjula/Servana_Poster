
import 'package:cloud_firestore/cloud_firestore.dart';
class PairMeta {
  final String posterId; final String helperId; final bool introFeePaid;
  final String? creditedToTaskId; final Timestamp? firstContactAt;
  PairMeta({required this.posterId, required this.helperId, required this.introFeePaid,
    this.creditedToTaskId, this.firstContactAt});
  Map<String, dynamic> toMap()=>{'posterId':posterId,'helperId':helperId,'introFeePaid':introFeePaid,
    'creditedToTaskId':creditedToTaskId,'firstContactAt':firstContactAt};
  static PairMeta fromDoc(DocumentSnapshot doc){final d=doc.data() as Map<String,dynamic>? ?? {};
    return PairMeta(posterId:d['posterId']??'',helperId:d['helperId']??'',
      introFeePaid:(d['introFeePaid']??false) as bool,creditedToTaskId:d['creditedToTaskId'],
      firstContactAt:d['firstContactAt']);}
  static String docId(String posterId,String helperId)=>'${posterId}_${helperId}';
}
