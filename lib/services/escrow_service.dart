
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/payments_config.dart';
class EscrowService {
  EscrowService._(); static final EscrowService instance = EscrowService._();
  final _db = FirebaseFirestore.instance;
  Future<int> computeDepositCoins(int budgetLkr) async {
    final pct=(budgetLkr*PaymentsConfig.depositPercentOfBudget).round();
    return pct<PaymentsConfig.minDepositCoins?PaymentsConfig.minDepositCoins:pct;
  }
  Future<void> lockDepositCoins({required String posterId, required String taskId, required int depositCoins}) async {
    final userRef=_db.collection('users').doc(posterId); final taskRef=_db.collection('tasks').doc(taskId);
    final txRef=_db.collection('transactions').doc();
    await _db.runTransaction((txn) async {
      final userSnap=await txn.get(userRef); final data=userSnap.data() as Map<String,dynamic>? ?? {};
      final current=(data['coinBalance']??0) as int; if(current<depositCoins) { throw Exception('INSUFFICIENT_COINS'); }
      final locked=(data['coinLocked']??0) as int;
      txn.update(userRef,{'coinBalance':current-depositCoins,'coinLocked':locked+depositCoins});
      txn.set(txRef,{'type':'escrowHold','method':'coins','amountCoins':depositCoins,'taskId':taskId,
        'posterId':posterId,'createdAt':FieldValue.serverTimestamp()});
      txn.set(taskRef,{'escrow':{'method':'coins','amount':depositCoins,'locked':true,'status':'held'}},SetOptions(merge:true));
    });
  }
  Future<void> releaseDeposit({required String posterId, required String taskId, required int depositCoins}) async {
    final userRef=_db.collection('users').doc(posterId); final taskRef=_db.collection('tasks').doc(taskId);
    final txRef=_db.collection('transactions').doc();
    await _db.runTransaction((txn) async {
      final userSnap=await txn.get(userRef); final data=userSnap.data() as Map<String,dynamic>? ?? {};
      final locked=(data['coinLocked']??0) as int;
      txn.update(userRef,{'coinBalance':(data['coinBalance']??0)+depositCoins,'coinLocked':(locked - depositCoins).clamp(0, 1<<31)});
      txn.set(txRef,{'type':'escrowRelease','method':'coins','amountCoins':depositCoins,'taskId':taskId,
        'posterId':posterId,'createdAt':FieldValue.serverTimestamp()});
      txn.set(taskRef,{'escrow':{'status':'released','locked':false}},SetOptions(merge:true));
    });
  }
}
