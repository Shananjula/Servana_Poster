// lib/screens/shortlist_screen.dart
//
// ShortlistScreen — saved helpers with compare
// Source: shortlists/{uid}/helpers/{helperId} -> { savedAt, data }
// - Multi-select up to 3 for comparison
// - Uses HelperCard for consistent look
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:servana/widgets/helper_card.dart';
import 'package:servana/screens/compare_helpers_screen.dart';

class ShortlistScreen extends StatefulWidget {
  const ShortlistScreen({super.key});

  @override
  State<ShortlistScreen> createState() => _ShortlistScreenState();
}

class _ShortlistScreenState extends State<ShortlistScreen> {
  final _selected = <String, Map<String, dynamic>>{};

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(appBar: AppBar(title: const Text('Shortlist')), body: const Center(child: Text('Sign in to view your shortlist.')));
    }

    final q = FirebaseFirestore.instance
        .collection('shortlists')
        .doc(uid)
        .collection('helpers')
        .orderBy('savedAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shortlist'),
        actions: [
          if (_selected.isNotEmpty)
            TextButton.icon(
              onPressed: _selected.length >= 2 && _selected.length <= 3
                  ? () {
                      final helpers = _selected.values.toList();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompareHelpersScreen(helpers: helpers)));
                    }
                  : null,
              icon: const Icon(Icons.compare_rounded),
              label: Text('Compare (${_selected.length})'),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No saved helpers yet. Tap the heart on a card to save.'));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final d = docs[i].data();
              final h = Map<String, dynamic>.from((d['data'] ?? {}) as Map);
              final id = h['id']?.toString() ?? docs[i].id;
              final checked = _selected.containsKey(id);

              return Stack(
                children: [
                  HelperCard(data: h, onViewProfile: null),
                  Positioned(
                    right: 8, top: 8,
                    child: FilterChip(
                      label: const Text('Compare'),
                      selected: checked,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            if (_selected.length < 3) _selected[id] = h;
                          } else {
                            _selected.remove(id);
                          }
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
