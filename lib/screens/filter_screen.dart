// lib/screens/filter_screen.dart
//
// Universal Filters (Posters & Helpers)
// -------------------------------------
// • Category multi-select
// • Distance slider (1–15 km)
// • Price range (min/max, LKR)
// • Rating (min, 0–5)
// • Type: Physical / Online / All
// • Verified-only toggle (for helpers/posters lists)
// • Live-only toggle (for "who is online/nearby" lists)
// • Optional "Save alert" → saved_searches/{id}
//
// Backward compatible constructor:
//   const FilterScreen({ Key? key, this.scrollController, this.initialFilters, this.roleIsHelper = false })
//
// On Apply: pops with a Map<String, dynamic> of filters.
// On Cancel: pops with null.
//
// If you previously required scrollController/initialFilters, they are now optional,
// so you can safely call `FilterScreen()` without args.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({
    super.key,
    this.scrollController,
    this.initialFilters,
    this.roleIsHelper = false,
  });

  /// Optional external scroll controller (old signature compatibility)
  final ScrollController? scrollController;

  /// Optional initial filter map (old signature compatibility)
  final Map<String, dynamic>? initialFilters;

  /// Whether the current UI role is helper (affects some labels)
  final bool roleIsHelper;

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // Keep consistent with your app categories
  static const List<String> _kCategories = <String>[
    'Cleaning', 'Delivery', 'Repairs', 'Tutoring', 'Design', 'Writing',
  ];

  // --- Local filter state ---
  final Set<String> _categories = {};
  double _distanceKm = 4;

  final TextEditingController _minPrice = TextEditingController();
  final TextEditingController _maxPrice = TextEditingController();

  double _minRating = 0;           // 0..5
  String _type = 'all';            // all | physical | online
  bool _verifiedOnly = false;
  bool _liveOnly = false;

  // Saved alert
  bool _saveAlert = false;
  final TextEditingController _alertName = TextEditingController();
  bool _savingAlert = false;

  @override
  void initState() {
    super.initState();
    _primeFromInitial(widget.initialFilters ?? const {});
  }

  @override
  void dispose() {
    _minPrice.dispose();
    _maxPrice.dispose();
    _alertName.dispose();
    super.dispose();
  }

  void _primeFromInitial(Map<String, dynamic> initial) {
    final cats = (initial['categories'] as List?)?.cast<String>() ?? const <String>[];
    _categories.addAll(cats);

    _distanceKm = ((initial['distanceKm'] as num?)?.toDouble() ?? 4).clamp(1.0, 15.0);
    _minPrice.text = (initial['minPrice']?.toString() ?? '');
    _maxPrice.text = (initial['maxPrice']?.toString() ?? '');

    _minRating = ((initial['minRating'] as num?)?.toDouble() ?? 0).clamp(0, 5);
    _type = (initial['type'] as String?) ?? 'all';
    _verifiedOnly = (initial['verifiedOnly'] as bool?) ?? false;
    _liveOnly = (initial['liveOnly'] as bool?) ?? false;
  }

  Map<String, dynamic> _collect() {
    return {
      'categories': _categories.toList(),
      'distanceKm': _distanceKm,
      'minPrice': int.tryParse(_minPrice.text.trim()),
      'maxPrice': int.tryParse(_maxPrice.text.trim()),
      'minRating': _minRating,
      'type': _type,               // all|physical|online
      'verifiedOnly': _verifiedOnly,
      'liveOnly': _liveOnly,
    };
  }

  Future<void> _saveSearchAlert() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in first.')));
      return;
    }
    setState(() => _savingAlert = true);
    try {
      await FirebaseFirestore.instance.collection('saved_searches').add({
        'userId': uid,
        'name': _alertName.text.trim().isEmpty ? 'My saved search' : _alertName.text.trim(),
        'filters': _collect(),
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert saved.')));
      setState(() => _saveAlert = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save alert: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingAlert = false);
    }
  }

  void _apply() => Navigator.pop(context, _collect());
  void _reset() {
    setState(() {
      _categories.clear();
      _distanceKm = 4;
      _minPrice.clear();
      _maxPrice.clear();
      _minRating = 0;
      _type = 'all';
      _verifiedOnly = false;
      _liveOnly = false;
      _saveAlert = false;
      _alertName.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final forHelper = widget.roleIsHelper;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filters'),
        actions: [ TextButton(onPressed: _reset, child: const Text('Reset')) ],
      ),
      body: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          // Categories
          _Section('Categories'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kCategories.map((c) {
                  final on = _categories.contains(c);
                  return FilterChip(
                    label: Text(c),
                    selected: on,
                    onSelected: (v) => setState(() => v ? _categories.add(c) : _categories.remove(c)),
                  );
                }).toList(),
              ),
            ),
          ),

          // Distance
          _Section('Distance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      min: 1, max: 15, divisions: 14,
                      label: '${_distanceKm.toStringAsFixed(0)} km',
                      value: _distanceKm,
                      onChanged: (v) => setState(() => _distanceKm = v),
                    ),
                  ),
                  SizedBox(width: 64, child: Text('${_distanceKm.toStringAsFixed(0)} km', textAlign: TextAlign.end)),
                ],
              ),
            ),
          ),

          // Price range
          _Section('Price'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPrice, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min (LKR)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxPrice, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max (LKR)'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Rating
          _Section('Rating'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      min: 0, max: 5, divisions: 10,
                      label: _minRating.toStringAsFixed(1),
                      value: _minRating,
                      onChanged: (v) => setState(() => _minRating = v),
                    ),
                  ),
                  SizedBox(width: 48, child: Text(_minRating.toStringAsFixed(1), textAlign: TextAlign.end)),
                ],
              ),
            ),
          ),

          // Type & flags
          _Section('Type'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('All')),
                      ButtonSegment(value: 'physical', label: Text('Physical')),
                      ButtonSegment(value: 'online', label: Text('Online')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() => _type = s.first),
                  ),
                  const Divider(height: 16),
                  SwitchListTile(
                    value: _verifiedOnly,
                    onChanged: (v) => setState(() => _verifiedOnly = v),
                    title: const Text('Verified only'),
                    subtitle: Text(forHelper
                        ? 'Show only posters with a verification badge (if collected).'
                        : 'Show only helpers with a verification badge.'),
                    secondary: const Icon(Icons.verified_outlined),
                  ),
                  SwitchListTile(
                    value: _liveOnly,
                    onChanged: (v) => setState(() => _liveOnly = v),
                    title: const Text('Live only'),
                    subtitle: Text(forHelper
                        ? 'Show only tasks currently in live window.'
                        : 'Show only helpers who are live now.'),
                    secondary: const Icon(Icons.podcasts_outlined),
                  ),
                ],
              ),
            ),
          ),

          // Saved alert
          _Section('Saved alert (optional)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _saveAlert,
                    onChanged: (v) => setState(() => _saveAlert = v),
                    title: const Text('Save these filters as an alert'),
                    subtitle: const Text('We’ll notify you when new matches appear.'),
                  ),
                  if (_saveAlert) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _alertName,
                      decoration: const InputDecoration(
                        labelText: 'Alert name',
                        hintText: 'e.g., Tutoring ≤5km ≥4★',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: _savingAlert ? null : _saveSearchAlert,
                        icon: _savingAlert
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: const Text('Save alert'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // Apply bar
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(onPressed: _apply, icon: const Icon(Icons.check), label: const Text('Apply'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 6, left: 4, top: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium));
}
