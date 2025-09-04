
import 'package:cloud_firestore/cloud_firestore.dart';
class PaymentsService {
  PaymentsService._(); static final PaymentsService instance = PaymentsService._();
  final _db = FirebaseFirestore.instance;
  Future<void> recordTopUpCoins({required String userId, required int amountCoins, String? methodNote}) async {
    final userRef=_db.collection('users').doc(userId); final txRef=_db.collection('transactions').doc();
    await _db.runTransaction((txn) async {
      final userSnap=await txn.get(userRef); final data=userSnap.data() as Map<String,dynamic>? ?? {};
      txn.update(userRef,{'coinBalance':(data['coinBalance']??0)+amountCoins});
      txn.set(txRef,{'type':'topup','method':'coins','amountCoins':amountCoins,'userId':userId,
        'note':methodNote,'createdAt':FieldValue.serverTimestamp()});
    });
  }
}
