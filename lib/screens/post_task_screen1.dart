
// lib/screens/post_task_screen.dart
//
// Poster → Post a Task (draft -> publish via Cloud Function)
// Implements Map v2.2:
//  - Poster needs >500 coins to publish (rules + CF enforce; this screen surfaces the message)
//  - Creates/updates a DRAFT doc locally, then calls CF `publishTask` to open it
//  - Category picker writes categoryId; mode selector sets 'mode': 'online'|'physical'
//  - Minimal UI — keep your advanced fields if you have them elsewhere

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PostTaskScreen extends StatefulWidget {
  const PostTaskScreen({super.key});

  @override
  State<PostTaskScreen> createState() => _PostTaskScreenState();
}

class _PostTaskScreenState extends State<PostTaskScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _mode = 'online'; // 'online' | 'physical'
  String? _categoryId;
  bool _busy = false;
  String? _error;
  String? _draftTaskId;

  File? _coverFile;
  double? _lat, _lng;
  String? _address;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a task')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Mode:'),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Online'),
                  selected: _mode == 'online',
                  onSelected: (v) => setState(() => _mode = 'online'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Physical'),
                  selected: _mode == 'physical',
                  onSelected: (v) => setState(() => _mode = 'physical'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CategoryDropdown(
              value: _categoryId,
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            if (_mode == 'physical')
              ListTile(
                title: Text(_address ?? 'Pick location'),
                subtitle: (_lat != null && _lng != null) ? Text('$_lat, $_lng') : null,
                trailing: const Icon(Icons.map),
                onTap: _pickLocation,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickCover,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Cover photo'),
                ),
                const SizedBox(width: 12),
                if (_coverFile != null) Text(_coverFile!.path.split('/').last),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _publish,
              child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Publish'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCover() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (p == null) return;
    setState(() => _coverFile = File(p.path));
  }

  Future<void> _pickLocation() async {
    // Stub for your existing map picker; keep your implementation if you have one.
    // Here we just assign some dummy coordinates.
    setState(() {
      _lat = 6.9271;
      _lng = 79.8612;
      _address = "Colombo, Sri Lanka";
    });
  }

  Future<void> _ensureDraft() async {
    if (_draftTaskId != null) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = await FirebaseFirestore.instance.collection('tasks').add({
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'posterId': uid,
      'mode': _mode,
      'categoryId': _categoryId,
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      if (_mode == 'physical') ...{
        'lat': _lat,
        'lng': _lng,
        'address': _address,
      },
    });
    _draftTaskId = ref.id;
  }

  Future<void> _publish() async {
    setState(() { _busy = true; _error = null; });
    try {
      if (_categoryId == null || _categoryId!.isEmpty) {
        throw Exception('Pick a category first');
      }
      await _ensureDraft();

      final callable = FirebaseFunctions.instance.httpsCallable('publishTask');
      final res = await callable.call({
        'taskId': _draftTaskId,
        // You can pass additional fields to be merged by CF if your backend supports it
        'status': 'open',
      });
      final data = (res.data is Map) ? (res.data as Map) : {};
      final tid = (data['taskId'] ?? data['id'] ?? _draftTaskId).toString();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task published: $tid')),
      );
      Navigator.of(context).pop(tid);
    } on FirebaseFunctionsException catch (e) {
      final msg = e.message ?? e.code;
      setState(() => _error = (e.code == 'failed-precondition' and msg.contains('min_balance'))
          ? 'You need more than 500 coins to post. Please top up.'
          : msg);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('categories').orderBy('name').snapshots(),
      builder: (context, snap) {
        final items = (snap.data?.docs ?? [])
            .map((d) => DropdownMenuItem<String>(value: d.id, child: Text(d.data()['name'] ?? d.id)))
            .toList();
        return DropdownButtonFormField<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        );
      },
    );
  }
}
