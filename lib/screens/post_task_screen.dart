// lib/screens/post_task_screen.dart
//
// Post a Task (Poster) — multi‑tag categories + named dropdowns + payment methods + AI draft (Map-safe)
//
// This replaces the previous screen and fixes:
//  • DropdownButtonFormField positional-args error (uses named params)
//  • AiService result treated as Map<String, dynamic>
//  • Adds optional multi-category tags (writes categoryId + categoryIds + categoryTokens)
//  • Preserves your existing UX: title, description, subcategory, task type, map, budgets, tags, cover photo
//  • Supports initialCategory to preselect the main category
//
// Firestore write (subset):
//   tasks/{id}:
//     title, description, type ('physical'|'online'), posterId, createdAt
//     category (label), subcategory (label)
//     categoryId (primary canonical id, slug)
//     categoryIds (List<String> of canonical ids)
//     categoryTokens (List<String> — same as ids for now)
//     budget or budgetMin/budgetMax
//     tags (List<String>), coverUrl, location (GeoPoint), address
//     paymentMethods (List<String>), paymentOtherNote (String?)

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Categories & helpers available in your repo
import 'package:servana/data/category_catalog.dart';
import 'package:servana/screens/map_picker_screen.dart';
import 'package:servana/services/ai_service.dart' as ai;

// Payment method enum added in your repo
import 'package:servana/models/payment_method.dart';

// --------------------
// Helpers for canonicalization & publishing
// --------------------

String _slug(String s) {
  final lower = s.trim().toLowerCase();
  // keep a-z, 0-9, replace others with "-"
  final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final stripped = replaced.replaceAll(RegExp(r'^-+|-+$'), '');
  return stripped;
}

Set<String> _canonSet(Iterable<String?> items) {
  final out = <String>{};
  for (final it in items) {
    if (it == null) continue;
    final s = _slug(it);
    if (s.isNotEmpty) out.add(s);
  }
  return out;
}

Future<String> publishTask({
  required String title,
  required String description,
  required String posterId,
  required bool isPhysical,
  String? mainCategoryLabelOrId,
  String? mainCategoryId,
  List<String>? extraCategoryLabelsOrIds,
  double? price,
  double? budgetMin,
  double? budgetMax,
  double? lat,
  double? lng,
  String? city,
  String? addressShort,
  List<String>? paymentMethods,
  String? paymentOtherNote,
  String? coverUrl,
  String? subcategory,
  List<String>? tags,
}) async {
  // Validate "other" payment note when chosen
  final pm = paymentMethods ?? const <String>[];
  if (pm.contains('other')) {
    if (paymentOtherNote == null || paymentOtherNote.trim().isEmpty) {
      throw Exception("Please add a note for 'Other' payment method.");
    }
  }

  final now = FieldValue.serverTimestamp();
  final type = isPhysical ? 'physical' : 'online';

  final primaryCatId = (mainCategoryId != null && mainCategoryId.isNotEmpty)
      ? _slug(mainCategoryId)
      : (mainCategoryLabelOrId != null ? _slug(mainCategoryLabelOrId) : null);

  final extraCatIdsSet = _canonSet(extraCategoryLabelsOrIds ?? const <String>[]);
  if (primaryCatId != null && primaryCatId.isNotEmpty) {
    extraCatIdsSet.remove(primaryCatId);
  }
  final categoryIds = <String>[
    if (primaryCatId != null && primaryCatId.isNotEmpty) primaryCatId,
    ...extraCatIdsSet,
  ];

  final data = <String, dynamic>{
    'title': title,
    'description': description,
    'type': type,
    'status': 'open',
    'posterId': posterId,
    'createdAt': now,
    'updatedAt': now,
    'isPhysical': isPhysical,

    // Categories
    if (mainCategoryLabelOrId != null) 'category': mainCategoryLabelOrId,
    if (mainCategoryLabelOrId != null) 'mainCategoryLabelOrId': mainCategoryLabelOrId,
    if (primaryCatId != null && primaryCatId.isNotEmpty) 'mainCategoryId': primaryCatId,
    if (primaryCatId != null && primaryCatId.isNotEmpty) 'categorySlug': primaryCatId,
    if (subcategory != null && subcategory.isNotEmpty) 'subcategory': subcategory,
    if (primaryCatId != null) 'categoryId': primaryCatId,
    if (categoryIds.isNotEmpty) 'categoryIds': categoryIds,
    if (categoryIds.isNotEmpty) 'categoryTokens': categoryIds,

    // Budget
    if (price != null) 'budget': price,
    if (budgetMin != null) 'budgetMin': budgetMin,
    if (budgetMax != null) 'budgetMax': budgetMax,

    // Location
    if (lat != null && lng != null) 'location': GeoPoint(lat, lng),
    if (addressShort != null && addressShort.isNotEmpty) 'address': addressShort,
    if (city != null && city.isNotEmpty) 'city': city,

    // Media
    if (coverUrl != null) 'coverUrl': coverUrl,

    // Payments
    if (pm.isNotEmpty) 'paymentMethods': pm,
    if (pm.contains('other') && paymentOtherNote != null) 'paymentOtherNote': paymentOtherNote,

    // Extra
    if (tags != null && tags.isNotEmpty) 'tags': tags,
    'isUrgent': false,
  };

  final doc = await FirebaseFirestore.instance.collection('tasks').add(data);
  return doc.id;
}

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
  final _paymentOtherCtrl = TextEditingController();

  // Category / Subcategory
  String? _categoryLabel; // e.g., "Cleaning"
  String? _subcategory;

  // Task type
  String _type = 'physical'; // 'physical' | 'online'

  // Payment methods (multi-select)
  final Set<PaymentMethod> _paymentMethods = <PaymentMethod>{};
  bool get _paymentHasOther => _paymentMethods.contains(PaymentMethod.other);

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
    if (widget.initialCategory != null && widget.initialCategory!.trim().isNotEmpty) {
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
    _paymentOtherCtrl.dispose();
    super.dispose();
  }

  // ---------------------------
  // Helpers
  // ---------------------------

  String _normalizeCategoryId(String? label) {
    final raw = (label ?? '').trim().toLowerCase();
    if (raw.isEmpty) return '';
    return raw.replaceAll(RegExp(r'\s+'), '_');
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _pickCover() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (p == null) return;
    setState(() => _coverFile = File(p.path));
  }

  Future<void> _pickLocation() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (res is Map && res['lat'] is num && res['lng'] is num) {
      setState(() {
        _lat = (res['lat'] as num).toDouble();
        _lng = (res['lng'] as num).toDouble();
        _address = (res['address'] as String?)?.trim();
      });
    }
  }

  num? _toNum(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return num.tryParse(t);
  }

  IconData _iconForCategory(String? label) {
    final c = (label ?? '').toLowerCase();
    if (c.contains('plumb')) return Icons.plumbing;
    if (c.contains('electric')) return Icons.electrical_services;
    if (c.contains('clean')) return Icons.cleaning_services;
    if (c.contains('move')) return Icons.local_shipping;
    if (c.contains('garden')) return Icons.park_rounded;
    if (c.contains('handy')) return Icons.handyman;
    if (c.contains('math')) return Icons.calculate;
    if (c.contains('science')) return Icons.science;
    if (c.contains('design')) return Icons.brush;
    return Icons.work_outline_rounded;
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final categories = (_type == 'physical'
        ? CategoryCatalog.physical
        : CategoryCatalog.online);

    // Ensure dropdown value is valid (avoid 'exactly one item with value' assertion)
    final String? categoryValue = () {
      final v = _categoryLabel;
      if (v == null) return null;
      if (categories.contains(v)) return v;
      final i = categories.indexWhere((c) => c.toLowerCase() == v.toLowerCase());
      return i == -1 ? null : categories[i];
    }();
    final subcats = categoryValue == null
        ? const <String>[]
        : (CategoryCatalog.byLabel[categoryValue] ?? const <String>[]);

    return Scaffold(
      appBar: AppBar(title: const Text('Post a task')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              // Title
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Fix leaking sink / Grade 8 maths tutor',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().length < 6) ? 'Enter at least 6 characters' : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descCtrl,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe the task clearly…',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().length < 20) ? 'Enter at least 20 characters' : null,
              ),
              const SizedBox(height: 16),

              // Category + Subcategory (NAMED args)
              Row(
                children: [
                  // Category
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: categoryValue,
                      selectedItemBuilder: (ctx) => categories
                          .map<Widget>((label) => Text(label, overflow: TextOverflow.ellipsis))
                          .toList(),
                      items: categories
                          .map((label) => DropdownMenuItem(
                        value: label,
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Icon(_iconForCategory(label), color: cs.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                  // Subcategory
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _subcategory,
                      selectedItemBuilder: (ctx) => subcats
                          .map<Widget>((label) => Text(label, overflow: TextOverflow.ellipsis))
                          .toList(),
                      items: subcats
                          .map((label) => DropdownMenuItem(
                        value: label,
                        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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

              const SizedBox(height: 12),


              const SizedBox(height: 12),

              // Task type
              Text('Task type', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'physical', label: Text('Physical'), icon: Icon(Icons.location_on_rounded)),
                  ButtonSegment(value: 'online', label: Text('Online'), icon: Icon(Icons.public_rounded)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  final labels = (_type == 'physical')
                      ? CategoryCatalog.physical
                      : CategoryCatalog.online;
                  if (_categoryLabel != null && !labels.contains(_categoryLabel)) {
                    _categoryLabel = null;
                    _subcategory = null;
                  }
                }),
              ),

              // Location (physical only)
              if (_type == 'physical') ...[
                const SizedBox(height: 12),
                Text('Location', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(_address ?? 'No location selected',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: (_address == null) ? theme.colorScheme.onSurfaceVariant : null)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: _pickLocation,
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('Pick on map'),
                    ),
                  ],
                ),
              ],

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
                        labelText: 'Fixed (LKR) — optional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _budgetMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min (LKR) — optional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _budgetMaxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max (LKR) — optional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Payment methods
              Text('Accepted payment methods', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: -6,
                children: [
                  for (final m in PaymentMethod.values)
                    FilterChip(
                      selected: _paymentMethods.contains(m),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(m.icon, size: 16),
                          const SizedBox(width: 6),
                          Text(m.label),
                        ],
                      ),
                      onSelected: (on) {
                        setState(() {
                          if (on) {
                            _paymentMethods.add(m);
                          } else {
                            _paymentMethods.remove(m);
                          }
                        });
                      },
                    ),
                ],
              ),
              if (_paymentHasOther) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _paymentOtherCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Other (specify)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Tags
              TextFormField(
                controller: _tagsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated, optional)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // Cover image
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickCover,
                      icon: const Icon(Icons.image_rounded),
                      label: const Text('Add cover photo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_coverFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_coverFile!, width: 72, height: 72, fit: BoxFit.cover),
                    ),
                ],
              ),
              if (_uploadingImage) ...[
                const SizedBox(height: 6),
                const LinearProgressIndicator(minHeight: 4),
              ],

              const SizedBox(height: 12),
              if (_priceHint != null)
                Text(_priceHint!, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),

              const SizedBox(height: 16),

              // Generate (AI)
              FilledButton.tonalIcon(
                onPressed: _generateWithAi,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('✨ Generate for me'),
              ),

              const SizedBox(height: 12),

              // Post
              FilledButton.icon(
                onPressed: _submitting ? null : _saveTask,
                icon: const Icon(Icons.send_rounded),
                label: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Post task'),
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

  Future<void> _generateWithAi() async {
    if (_titleCtrl.text.trim().isEmpty && _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a brief description first.')));
      return;
    }
    try {
      setState(() => _priceHint = 'Thinking…');

      final res = await ai.AiService.draftTaskFromText(
        title: _titleCtrl.text,
        description: _descCtrl.text,
      );

      // Treat as Map to be compatible with your AiService return type
      final Map<String, dynamic> draft =
      (res is Map<String, dynamic>) ? res : <String, dynamic>{};

      final String? draftTitle       = draft['title'] as String?;
      final String? draftDescription = draft['description'] as String?;
      final String? draftCategory    = draft['category'] as String?;
      final String? draftPriceHint   = draft['priceHint'] as String?;

      if (!mounted) return;
      setState(() {
        if (draftTitle != null && draftTitle.trim().isNotEmpty) {
          _titleCtrl.text = draftTitle;
        }
        if (draftDescription != null && draftDescription.trim().isNotEmpty) {
          _descCtrl.text = draftDescription;
        }
        if (draftCategory != null && draftCategory.trim().isNotEmpty) {
          _categoryLabel = draftCategory;
          _subcategory = null;
        }
        if (draftPriceHint != null && draftPriceHint.trim().isNotEmpty) {
          _priceHint = draftPriceHint;
        } else {
          _priceHint = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _priceHint = null);
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryLabel == null || _categoryLabel!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a category.')));
      return;
    }
    setState(() => _submitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('Not signed in');
      }

      // Upload cover image if present
      String? coverUrl;
      if (_coverFile != null) {
        setState(() => _uploadingImage = true);
        final ref = FirebaseStorage.instance
            .ref('task_covers/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_coverFile!);
        coverUrl = await ref.getDownloadURL();
        setState(() => _uploadingImage = false);
      }

      // Budget parse (single or range)
      final double? single = _budgetSingleCtrl.text.trim().isEmpty ? null : double.tryParse(_budgetSingleCtrl.text.trim());
      final double? minB = _budgetMinCtrl.text.trim().isEmpty ? null : double.tryParse(_budgetMinCtrl.text.trim());
      final double? maxB = _budgetMaxCtrl.text.trim().isEmpty ? null : double.tryParse(_budgetMaxCtrl.text.trim());

      // Canonical category id for primary
      final primaryCategoryId = _normalizeCategoryId(_categoryLabel);

      // Payment methods
      final List<String> paymentIds = _paymentMethods.map((m) => m.id).toList();
      final String? paymentOtherNote =
      _paymentHasOther ? (_paymentOtherCtrl.text.trim().isEmpty ? null : _paymentOtherCtrl.text.trim()) : null;

      // Tags
      final List<String> tags = _parseTags(_tagsCtrl.text);

      final String newId = await publishTask(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        posterId: uid,
        isPhysical: _type == 'physical',
        mainCategoryLabelOrId: _categoryLabel,
        mainCategoryId: primaryCategoryId,
        price: single,
        budgetMin: minB,
        budgetMax: maxB,
        lat: _lat,
        lng: _lng,
        addressShort: _address,
        paymentMethods: paymentIds,
        paymentOtherNote: paymentOtherNote,
        coverUrl: coverUrl,
        subcategory: _subcategory,
        tags: tags,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task posted!')));
      Navigator.pop(context, {'taskId': newId});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

}
