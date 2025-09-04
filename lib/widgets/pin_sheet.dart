import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum PinMode { start, finish }

Future<bool?> showPinSheet(BuildContext context, {required PinMode mode, required String taskId}) async {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PinSheet(mode: mode, taskId: taskId),
  );
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.mode, required this.taskId});
  final PinMode mode;
  final String taskId;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _pin = TextEditingController();
  bool _busy = false;
  String? _expected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).get();
    final data = doc.data() ?? {};
    setState(() {
      _expected = widget.mode == PinMode.start ? data['startPin']?.toString() : data['finishPin']?.toString();
    });
  }

  Future<void> _commit() async {
    final pin = _pin.text.trim();
    if (pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a 4-digit PIN')));
      return;
    }
    setState(() => _busy = true);
    try {
      final ref = FirebaseFirestore.instance.collection('tasks').doc(widget.taskId);
      final now = FieldValue.serverTimestamp();
      if (_expected != null && _expected!.isNotEmpty && _expected != pin) {
        throw Exception('Incorrect PIN');
      }
      if (widget.mode == PinMode.start) {
        await ref.set({'status':'ongoing','startedAt':now, if (_expected==null||_expected!.isEmpty) 'pinStartEntered':pin,'updatedAt':now}, SetOptions(merge:true));
      } else {
        await ref.set({'status':'completed','finishedAt':now, if (_expected==null||_expected!.isEmpty) 'pinFinishEntered':pin,'updatedAt':now}, SetOptions(merge:true));
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.mode == PinMode.start ? 'Start PIN' : 'Finish PIN';
    final hint = _expected == null || _expected!.isEmpty ? '$label (set by helper or ops)' : label;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              controller: _pin,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: hint, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: FilledButton.icon(icon: _busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.check_circle_rounded), label: const Text('Confirm'), onPressed: _busy?null:_commit))]),
          ],
        ),
      ),
    );
  }
}
