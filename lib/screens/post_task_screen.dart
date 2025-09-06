// lib/screens/post_task_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'map_picker_screen.dart';
import '../models/payment_method.dart';
import '../widgets/payment_methods_picker.dart';

class PostTaskScreen extends StatefulWidget {
  const PostTaskScreen({super.key, this.initialCategory});
  final String? initialCategory;

  @override
  State<PostTaskScreen> createState() => _PostTaskScreenState();
}

class _PostTaskScreenState extends State<PostTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  // Core fields
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController(); // single price
  final _minCtrl = TextEditingController(); // optional range
  final _maxCtrl = TextEditingController();
  String? _categoryLabel;
  String? _subcategory;
  String _type = 'physical'; // 'physical' | 'online'

  // Location (physical only)
  double? _lat;
  double? _lng;
  String? _address;

  // Optional cover
  File? _coverFile;
  bool _uploadingImage = false;

  // Payment methods
  Set<PaymentMethod> _methods = {PaymentMethod.servcoins};
  String? _otherNote;

  bool _submitting = false;

  num? _asNum(String s) => num.tryParse(s.trim());

  Future<void> _pickCover() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    setState(() => _coverFile = File(img.path));
  }

  Future<void> _pickLocation() async {
    final res = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (res == null) return;
    setState(() {
      _lat = (res['lat'] as num).toDouble();
      _lng = (res['lng'] as num).toDouble();
      _address = res['address'] as String?;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    // Budget sanity
    final single = _asNum(_budgetCtrl.text);
    final minB = _asNum(_minCtrl.text);
    final maxB = _asNum(_maxCtrl.text);
    if (single == null && minB == null && maxB == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a budget or a range')));
      return;
    }
    if (minB != null && maxB != null && minB > maxB) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Min cannot be greater than Max')));
      return;
    }
    // Payment methods sanity
    final ids = _methods.map((e) => e.id).toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one payment method')));
      return;
    }
    if (ids.contains('other') && (_otherNote == null || _otherNote!.trim().length < 3)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Describe the “Other” method')));
      return;
    }

    if (_type == 'physical' && (_lat == null || _lng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a location for a physical task')));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to post')));
      return;
    }

    setState(() => _submitting = true);
    try {
      // Upload cover (optional)
      String? coverUrl;
      if (_coverFile != null) {
        setState(() => _uploadingImage = true);
        final ref = FirebaseStorage.instance
            .ref()
            .child('task_covers')
            .child('${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_coverFile!);
        coverUrl = await ref.getDownloadURL();
        setState(() => _uploadingImage = false);
      }

      // 1) Create DRAFT task
      final now = FieldValue.serverTimestamp();
      final draft = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _categoryLabel,
        'subcategory': _subcategory,
        'type': _type,
        'status': 'draft',
        'posterId': uid,
        'createdAt': now,
        if (single != null) 'budget': single,
        if (minB != null) 'budgetMin': minB,
        if (maxB != null) 'budgetMax': maxB,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (_lat != null && _lng != null) 'location': GeoPoint(_lat!, _lng!),
        if (_address != null) 'address': _address,
        // NEW fields
        'paymentMethods': ids,
        if (ids.contains('other')) 'paymentOtherNote': _otherNote?.trim(),
      };

      final doc = await FirebaseFirestore.instance.collection('tasks').add(draft);

      // 2) Server-authoritative publish (min-balance ≥ 200, fee %, flip to open)
      final callable = FirebaseFunctions.instance.httpsCallable('publishTask');
      await callable.call({
        'taskId': doc.id,
        'idempotencyKey': '${uid}_${doc.id}_${DateTime.now().millisecondsSinceEpoch}',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task published')));
      Navigator.pop(context, {'taskId': doc.id});
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final msg = (e.code == 'failed-precondition' && (e.message?.contains('insufficient_funds') ?? false))
          ? 'You need at least 200 coins to post. Top up from Wallet.'
          : (e.message ?? e.code);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Post a task')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'E.g., Deep cleaning for 2-bedroom apartment',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().length < 8) ? 'Please enter at least 8 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),
              Text('Task type', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'physical', label: Text('Physical'), icon: Icon(Icons.location_on_rounded)),
                  ButtonSegment(value: 'online', label: Text('Online'), icon: Icon(Icons.public_rounded)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),

              const SizedBox(height: 12),
              Text('Budget', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _budgetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Budget (LKR)',
                        hintText: 'e.g., 5000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('or', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min (LKR)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max (LKR)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              PaymentMethodsPicker(
                initial: _methods,
                initialOtherNote: _otherNote,
                onChanged: (m, note) {
                  _methods = m;
                  _otherNote = note;
                },
              ),

              const SizedBox(height: 12),
              if (_type == 'physical')
                Row(
                  children: [
                    Expanded(
                      child: Text(_address ?? 'No location selected',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('Pick location'),
                      onPressed: _pickLocation,
                    ),
                  ],
                ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickCover,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_coverFile == null ? 'Add a cover photo' : 'Change photo'),
                    ),
                  ),
                  if (_uploadingImage) ...[
                    const SizedBox(width: 8),
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ],
              ),

              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded),
                label: const Text('Publish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
