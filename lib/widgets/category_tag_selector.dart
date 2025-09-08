import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CategoryTagSelector extends StatefulWidget {
  const CategoryTagSelector({
    super.key,
    required this.initialSelectedIds,
    required this.onChanged,
    this.hintText = 'Add categories…',
    this.maxSelectable = 5,
  });

  final List<String> initialSelectedIds;
  final ValueChanged<List<String>> onChanged;
  final String hintText;
  final int maxSelectable;

  @override
  State<CategoryTagSelector> createState() => _CategoryTagSelectorState();
}

class _CategoryTagSelectorState extends State<CategoryTagSelector> {
  final _searchCtrl = TextEditingController();
  final _selected = <String>{};
  Map<String, String> _namesById = {}; // id -> name

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelectedIds);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            labelText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('categories').orderBy('name').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: Padding(
                  padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
            }
            final q = (_searchCtrl.text.trim().toLowerCase());
            final docs = snap.data!.docs.where((d) {
              final data = d.data();
              final name = (data['name'] as String? ?? d.id).toLowerCase();
              final id = d.id.toLowerCase();
              if (q.isEmpty) return true;
              return name.contains(q) || id.contains(q);
            }).toList();

            _namesById = {
              for (final d in snap.data!.docs)
                d.id: (d.data()['name'] as String? ?? d.id)
            };

            return Wrap(
              spacing: 8,
              runSpacing: -6,
              children: docs.map((d) {
                final id = d.id;
                final name = (d.data()['name'] as String? ?? id);
                final selected = _selected.contains(id);
                return FilterChip(
                  label: Text(name),
                  selected: selected,
                  onSelected: (on) {
                    setState(() {
                      if (on) {
                        if (_selected.length < widget.maxSelectable) {
                          _selected.add(id);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('You can select up to ${widget.maxSelectable} categories.')),
                          );
                        }
                      } else {
                        _selected.remove(id);
                      }
                    });
                    widget.onChanged(_selected.toList());
                  },
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        if (_selected.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: -6,
            children: _selected.map((id) {
              final name = _namesById[id] ?? id;
              return Chip(
                label: Text(name),
                deleteIcon: const Icon(Icons.close),
                onDeleted: () {
                  setState(() { _selected.remove(id); });
                  widget.onChanged(_selected.toList());
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}
