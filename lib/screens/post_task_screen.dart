// lib/screens/post_task_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Your existing categories source (keys → subcats)
import 'package:servana/constants/service_categories.dart' as cats;
import 'package:servana/screens/map_picker_screen.dart';
// Alias to avoid any naming collisions with other AppServices
import 'package:servana/services/ai_service.dart' as ai;

// Post a Task (Poster)
// - Keeps a simple, robust form: title, description, category/subcategory,
//   task type (Online / Physical), budget (min/max OR one number), optional tags,
//   optional cover image, and optional map location for Physical tasks.
// - NEW: “✨ Generate for me” button uses AiService.draftTaskFromText(...) to
//   draft a better title, pick a category, tags and a fair price range.
// - Price hint: shows “Similar jobs nearby are LKR X–Y” (heuristic if AI is
//   unavailable).
// - Writes a doc to /tasks with status 'open' and posterId; other fields are
//   schema-tolerant and null-safe. No Firestore rules changes.

class PostTaskScreen extends StatefulWidget {
  const PostTaskScreen({super.key, this.initialCategory});
  final String? initialCategory;

  @override
  State<PostTaskScreen> createState() => _PostTaskScreenState();
}

class _PostTaskScreenState extends State<PostTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetMinCtrl = TextEditingController();
  final _budgetMaxCtrl = TextEditingController();
  final _budgetSingleCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  // Category / Subcategory
  String? _categoryLabel; // e.g., "Cleaning"
  String? _subcategory;

  // Task type
  String _type = 'physical'; // 'physical' | 'online'

  // Location (only for physical)
  double? _lat;
  double? _lng;
  String? _address;

  // Optional image
  File? _coverFile;
  bool _uploadingImage = false;

  // Submit state
  bool _submitting = false;

  // Price hint
  String? _priceHint; // "Similar jobs nearby are LKR X–Y"

  @override
  void initState() {
    super.initState();
    // Set the initial category if one was provided to the widget.
    if (widget.initialCategory != null) {
      _categoryLabel = widget.initialCategory;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    _budgetSingleCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final categories = cats.AppServices.categories.keys.toList(growable: false);
    final subcats = _categoryLabel == null
        ? const <String>[]
        : (cats.AppServices.categories[_categoryLabel!] ?? const <String>[]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post a task'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Title + Generate for me
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _titleCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'E.g., Deep cleaning for 2-bedroom apartment',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 8) {
                          return 'Please enter at least 8 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Generate title, category, tags and price hint',
                    child: FilledButton.icon(
                      onPressed: _onGeneratePressed,
                      icon: const Text('✨'),
                      label: const Text('Generate'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText:
                  'Tell helpers exactly what you need. Include size/scope, date/time, photos, and special notes.',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 20) {
                    return 'Please enter at least 20 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Category + Subcategory
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _categoryLabel,
                      items: categories
                          .map((label) => DropdownMenuItem(
                        value: label,
                        child: Row(
                          children: [
                            Icon(_iconForCategory(label), color: cs.primary),
                            const SizedBox(width: 8),
                            Text(label),
                          ],
                        ),
                      ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _categoryLabel = v;
                        _subcategory = null;
                      }),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null ? 'Select a category' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _subcategory,
                      items: subcats
                          .map((label) => DropdownMenuItem(
                        value: label,
                        child: Text(label),
                      ))
                          .toList(),
                      onChanged: (v) => setState(() => _subcategory = v),
                      decoration: const InputDecoration(
                        labelText: 'Subcategory (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Type
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

              const SizedBox(height: 16),

              // Budget
              Text('Budget', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _budgetSingleCtrl,
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
                      controller: _budgetMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min (LKR)',
                        hintText: 'e.g., 4000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _budgetMaxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max (LKR)',
                        hintText: 'e.g., 6000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (_priceHint != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _priceHint!,
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Tags
              TextFormField(
                controller: _tagsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated, optional)',
                  hintText: 'e.g., apartment, 2bhk, same-day',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // Location picker (physical only)
              if (_type == 'physical') _LocationCard(lat: _lat, lng: _lng, address: _address, onPick: _pickLocation),

              const SizedBox(height: 16),

              // Image picker
              _ImagePickerCard(
                file: _coverFile,
                uploading: _uploadingImage,
                onPick: _pickImage,
                onClear: () => setState(() => _coverFile = null),
              ),

              const SizedBox(height: 20),

              // Submit
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _onSubmit,
                  child: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Post task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------
  // Actions
  // ---------------------------

  Future<void> _onGeneratePressed() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (title.isEmpty && desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a short title or description first')),
      );
      return;
    }

    try {
      final draft = await ai.AiService.draftTaskFromText(title: title, description: desc);

      // Apply title/category/tags
      final newTitle = (draft['title'] as String?)?.trim();
      final newCat = (draft['category'] as String?)?.trim();
      final tags = (draft['tags'] as List?)?.whereType<String>().toList() ?? const <String>[];

      if (newTitle != null && newTitle.length >= 8) _titleCtrl.text = newTitle;
      if (newCat != null && newCat.isNotEmpty) {
        // Match label if present in your catalog, else just set as free text label
        final match = cats.AppServices.categories.keys.firstWhere(
              (l) => l.toLowerCase() == newCat.toLowerCase(),
          orElse: () => newCat,
        );
        setState(() {
          _categoryLabel = match;
          _subcategory = null;
        });
      }
      if (tags.isNotEmpty && _tagsCtrl.text.trim().isEmpty) {
        _tagsCtrl.text = tags.toSet().join(', ');
      }

      // Price band
      final band = draft['budgetRange'] is Map ? (draft['budgetRange'] as Map) : null;
      if (band != null && band.containsKey('min') && band.containsKey('max')) {
        final int min = (band['min'] as num).toInt();
        final int max = (band['max'] as num).toInt();
        setState(() {
          _priceHint = 'Similar jobs nearby are LKR ${_fmtInt(min)}–${_fmtInt(max)}';
          if (_budgetSingleCtrl.text.trim().isEmpty &&
              _budgetMinCtrl.text.trim().isEmpty &&
              _budgetMaxCtrl.text.trim().isEmpty) {
            _budgetMinCtrl.text = min.toString();
            _budgetMaxCtrl.text = max.toString();
          }
        });
      } else {
        _makeHeuristicHint();
      }
    } catch (_) {
      _makeHeuristicHint();
    }
  }

  Future<void> _makeHeuristicHint() async {
    // Conservative defaults by category using AiService bands if possible
    final band = ai.AiService.estimateBudgetBand(category: _categoryLabel);
    final int min = band?.$1 ?? 1500;
    final int max = band?.$2 ?? 6000;

    setState(() {
      _priceHint = 'Similar jobs nearby are LKR ${_fmtInt(min)}–${_fmtInt(max)}';
    });
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (!mounted || result == null) return;
    setState(() {
      _lat = (result['lat'] as num?)?.toDouble();
      _lng = (result['lng'] as num?)?.toDouble();
      _address = (result['address'] as String?)?.trim();
    });
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (x == null) return;
      setState(() => _coverFile = File(x.path));
    } catch (_) {
      // ignore
    }
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    // Basic budget validation
    final single = _asNum(_budgetSingleCtrl.text);
    final minB = _asNum(_budgetMinCtrl.text);
    final maxB = _asNum(_budgetMaxCtrl.text);
    if (single == null && minB == null && maxB == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter a budget or a range')));
      return;
    }
    if (minB != null && maxB != null && minB > maxB) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Min cannot be greater than Max')));
      return;
    }

    if (_type == 'physical' && (_lat == null || _lng == null)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please pick a location for a physical task')));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('You must be signed in to post')));
      return;
    }

    setState(() => _submitting = true);

    try {
      // Optional image upload
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

      // Compose task payload (schema tolerant)
      final now = FieldValue.serverTimestamp();
      final task = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _categoryLabel,
        'subcategory': _subcategory,
        'type': _type, // 'online' | 'physical'
        'status': 'open',
        'posterId': uid,
        'createdAt': now,
        'tags': _parseTags(_tagsCtrl.text),
        'isUrgent': false,
        if (single != null) 'budget': single,
        if (minB != null) 'budgetMin': minB,
        if (maxB != null) 'budgetMax': maxB,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (_lat != null && _lng != null) 'location': GeoPoint(_lat!, _lng!),
        if (_address != null) 'address': _address,
      };

      final doc = await FirebaseFirestore.instance.collection('tasks').add(task);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task posted!')),
      );
      Navigator.pop(context, {'taskId': doc.id});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to post: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------------------------
  // Helpers
  // ---------------------------
  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  num? _asNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().trim().replaceAll(',', '');
    if (s.isEmpty) return null;
    final n = num.tryParse(s);
    return n;
  }

  // Icon mapping that doesn’t rely on any external helper
  IconData _iconForCategory(String? label) {
    final c = (label ?? '').toLowerCase();
    if (c.contains('plumb')) return Icons.plumbing;
    if (c.contains('electric')) return Icons.electrical_services;
    if (c.contains('clean')) return Icons.cleaning_services;
    if (c.contains('paint')) return Icons.format_paint;
    if (c.contains('carp')) return Icons.chair_alt;
    if (c.contains('garden') || c.contains('yard')) return Icons.yard;
    if (c.contains('move') || c.contains('deliver')) return Icons.local_shipping;
    if (c.contains('ac') || c.contains('air')) return Icons.ac_unit;
    if (c.contains('repair') || c.contains('appliance')) return Icons.build;
    if (c.contains('design') || c.contains('graphic')) return Icons.brush;
    if (c.contains('computer') || c.contains('it')) return Icons.computer;
    if (c.contains('tuition') || c.contains('teach') || c.contains('class')) return Icons.school;
    return Icons.work_outline;
  }

  String _fmtInt(int n) {
    final s = n.abs().toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final withCommas = s.replaceAllMapped(reg, (m) => ',');
    return n < 0 ? '−$withCommas' : withCommas;
  }
}

// ---------------------------
// Sub-widgets
// ---------------------------

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.lat,
    required this.lng,
    required this.address,
    required this.onPick,
  });

  final double? lat;
  final double? lng;
  final String? address;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withOpacity(0.12)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.place_rounded),
        ),
        title: Text(
          address?.isNotEmpty == true
              ? address!
              : (lat != null && lng != null)
              ? 'Picked: ${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}'
              : 'Pick task location',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          address?.isNotEmpty == true
              ? 'Physical task at this address'
              : 'Required for physical tasks',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: FilledButton.tonal(
          onPressed: onPick,
          child: const Text('Pick'),
        ),
      ),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({
    required this.file,
    required this.uploading,
    required this.onPick,
    required this.onClear,
  });

  final File? file;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withOpacity(0.12)),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            shape: BoxShape.circle,
            image: file != null
                ? DecorationImage(image: FileImage(file!), fit: BoxFit.cover)
                : null,
          ),
          child: file == null ? const Icon(Icons.photo_library_rounded) : null,
        ),
        title: const Text('Cover image (optional)'),
        subtitle: Text(
          file == null ? 'Add a photo to attract more helpers' : 'Selected',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: uploading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (file != null)
              IconButton(
                tooltip: 'Remove',
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline),
              ),
            FilledButton.tonal(onPressed: onPick, child: const Text('Choose')),
          ],
        ),
      ),
    );
  }
}