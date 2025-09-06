// lib/widgets/multi_category_picker.dart
import 'package:flutter/material.dart';

class MultiCategoryPicker extends StatefulWidget {
  final List<String> initial; // initial selected ids
  final void Function(List<String> ids) onChanged;
  final List<Map<String, String>>? catalog; // optional custom catalog

  const MultiCategoryPicker({
    super.key,
    this.initial = const [],
    required this.onChanged,
    this.catalog,
  });

  @override
  State<MultiCategoryPicker> createState() => _MultiCategoryPickerState();
}

class _MultiCategoryPickerState extends State<MultiCategoryPicker> {
  // Minimal catalog; in production, load /categories from Firestore.
  late final List<Map<String, String>> _catalog = widget.catalog ?? const [
    {'id': 'tutoring', 'name': 'Tutoring'},
    {'id': 'tutoring_math', 'name': 'Math Tutoring'},
    {'id': 'tutoring_physics', 'name': 'Physics Tutoring'},
    {'id': 'design', 'name': 'Design'},
    {'id': 'logo_branding', 'name': 'Logo & Branding'},
  ];

  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = [...widget.initial];
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: -6,
      children: _catalog.map((c) {
        final id = c['id']!;
        final picked = _selected.contains(id);
        return FilterChip(
          label: Text(c['name'] ?? id),
          selected: picked,
          onSelected: (v) {
            setState(() {
              if (v) {
                if (!_selected.contains(id)) _selected.add(id);
              } else {
                _selected.remove(id);
              }
              widget.onChanged(_selected);
            });
          },
        );
      }).toList(),
    );
  }
}
