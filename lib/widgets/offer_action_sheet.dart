import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OfferActionSheet extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> offerSnap; // subcollection doc: tasks/{tid}/offers/{oid}
  const OfferActionSheet({super.key, required this.offerSnap});

  @override
  State<OfferActionSheet> createState() => _OfferActionSheetState();
}

class _OfferActionSheetState extends State<OfferActionSheet> {
  late final Map<String, dynamic> o = widget.offerSnap.data() ?? {};
  late final String offerId = widget.offerSnap.id;
  late final String taskId = (o['taskId'] ?? '').toString();
  final _counterCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final price = (o['counterPrice'] ?? o['price'] ?? o['amount'])?.toString() ?? '';
    _counterCtrl.text = price;
    _noteCtrl.text = (o['counterNote'] ?? '').toString();
  }

  Future<void> _ensureTopLevelOffer() async {
    // If you use mirroring triggers, this is already there. Otherwise, ensure a twin doc exists for acceptOffer CF.
    final top = FirebaseFirestore.instance.collection('offers').doc(offerId);
    final topSnap = await top.get();
    if (!topSnap.exists) {
      // get posterId from subdoc or from the task (for older docs)
      String? posterId = (o['posterId'] as String?);
      if (posterId == null || posterId.isEmpty) {
        final t = await FirebaseFirestore.instance.doc('tasks/$taskId').get();
        posterId = (t.data()??{})['posterId']?.toString();
      }
      await top.set({
        ...o,
        'taskId': taskId,
        if (posterId != null) 'posterId': posterId,
        '_mirroredFrom': 'tasks/$taskId/offers/$offerId',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _counter() async {
    setState(() => _busy = true);
    try {
      await widget.offerSnap.reference.update({
        'status': 'counter',
        'counterPrice': num.tryParse(_counterCtrl.text) ?? _counterCtrl.text,
        'counterNote': _noteCtrl.text.trim(),
        'counterBy': FirebaseAuth.instance.currentUser!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, 'countered');
    } catch (e) {
      if (mounted) _showSnack('Counter failed: $e');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await widget.offerSnap.reference.update({
        'status': 'rejected',
        'rejectReason': _noteCtrl.text.trim(),
        'rejectedBy': FirebaseAuth.instance.currentUser!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, 'rejected');
    } catch (e) {
      if (mounted) _showSnack('Reject failed: $e');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await _ensureTopLevelOffer(); // no-op if mirrored
      await FirebaseFunctions.instance
          .httpsCallable('acceptOffer')
          .call({'offerId': offerId});
      if (mounted) Navigator.pop(context, 'accepted');
    } on FirebaseFunctionsException catch (e) {
      _showSnack('Accept failed: ${e.code} ${e.message}');
    } catch (e) {
      _showSnack('Accept failed: $e');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final price = o['price'] ?? o['amount'];
    final helper = (o['helperName'] ?? o['helperId'] ?? '').toString();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text('Review offer', style: Theme.of(context).textTheme.titleLarge)),
                if (_busy) const SizedBox(width: 16),
                if (_busy) const CircularProgressIndicator(strokeWidth: 2),
              ],
            ),
            const SizedBox(height: 8),
            Text('From: $helper'),
            if (price != null) Text('Original: $price'),
            const SizedBox(height: 12),
            TextField(
              controller: _counterCtrl,
              decoration: const InputDecoration(
                labelText: 'Counter price',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _reject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _counter,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Counter'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _accept,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
