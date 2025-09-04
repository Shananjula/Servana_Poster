// lib/widgets/safety_sheet.dart
//
// SafetySheet — "I feel unsafe" flow
// - Lets poster send an SOS + (optional) live location to emergency contacts
// - Reads users/{uid}.emergencyContacts: [{name, phone}] (optional)
// - Writes to sosAlerts with timestamp. This is a lightweight starting point.
//
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> showSafetySheet(BuildContext context, {String? conversationId}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _SafetySheet(conversationId: conversationId),
  );
}

class _SafetySheet extends StatefulWidget {
  const _SafetySheet({this.conversationId});
  final String? conversationId;

  @override
  State<_SafetySheet> createState() => _SafetySheetState();
}

class _SafetySheetState extends State<_SafetySheet> {
  bool _shareLocation = true;
  final _note = TextEditingController();

  @override
  void dispose() { _note.dispose(); super.dispose(); }

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('sosAlerts').add({
        'userId': uid,
        'conversationId': widget.conversationId,
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'shareLocation': _shareLocation,
        'status': 'sent',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS sent to support. Stay safe.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [Icon(Icons.shield_rounded), SizedBox(width: 8), Text('I feel unsafe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _shareLocation,
              title: const Text('Share live location'),
              subtitle: const Text('Recommended — helps support or your contact reach you.'),
              onChanged: (v) => setState(() => _shareLocation = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Add a note (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: FilledButton.icon(icon: const Icon(Icons.sos_rounded), label: const Text('Send SOS'), onPressed: _send))]),
            const SizedBox(height: 8),
            Text('Tip: Add emergency contacts in Profile → Safety & privacy.', style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
