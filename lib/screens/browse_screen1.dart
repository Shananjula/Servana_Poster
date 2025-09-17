
// lib/screens/browse_screen.dart
//
// Poster → Browse helpers by category (eligible-only results) with direct-invite
// Implements Map v2.2:
//  - Posters MUST pick a category before seeing results
//  - Results include ONLY helpers verified for that category (allowedCategoryIds contains categoryId)
//  - Optional Online/Physical filters
//  - Invite button calls Cloud Function chargeDirectContactFee (poster pays 50 coins)
//
// NOTE: This screen intentionally does not allow posters to bypass eligibility; rules will enforce too.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> with AutomaticKeepAliveClientMixin {
  String? _selectedCategoryId;
  bool _online = true;
  bool _physical = true;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse helpers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: Theme.of(context).dividerColor),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _CategoryPicker(
            onChanged: (cid) => setState(() => _selectedCategoryId = cid),
            initialValue: _selectedCategoryId,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilterChip(
                label: const Text('Online'),
                selected: _online,
                onSelected: (v) => setState(() => _online = v),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Physical'),
                selected: _physical,
                onSelected: (v) => setState(() => _physical = v),
              ),
            ],
          ),
          const Divider(height: 24),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: _selectedCategoryId == null
                ? const _PickCategoryHint()
                : _HelperResults(
                    categoryId: _selectedCategoryId!,
                    online: _online,
                    physical: _physical,
                    onInvite: _inviteHelper,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteHelper(String helperId, String categoryId, {String? taskId}) async {
    setState(() { _busy = true; _error = null; });
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('chargeDirectContactFee');
      await callable.call({
        'helperId': helperId,
        'categoryId': categoryId,
        'taskId': taskId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite sent. 50 coins deducted.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  bool get wantKeepAlive => true;
}

class _PickCategoryHint extends StatelessWidget {
  const _PickCategoryHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Pick a category to find eligible helpers.\n'
          'Results only include helpers verified for that category.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String?> onChanged;
  const _CategoryPicker({required this.onChanged, this.initialValue});

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  String? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('categories').orderBy('name').snapshots(),
      builder: (context, snap) {
        final items = (snap.data?.docs ?? [])
            .map((d) => DropdownMenuItem<String>(
                  value: d.id,
                  child: Text(d.data()['name'] ?? d.id),
                ))
            .toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            value: _value,
            items: items,
            onChanged: (v) {
              setState(() => _value = v);
              widget.onChanged(v);
            },
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        );
      },
    );
  }
}

class _HelperResults extends StatelessWidget {
  final String categoryId;
  final bool online;
  final bool physical;
  final Future<void> Function(String helperId, String categoryId, {String? taskId}) onInvite;

  const _HelperResults({required this.categoryId, required this.online, required this.physical, required this.onInvite});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'helper')
        .where('allowedCategoryIds', arrayContains: categoryId);

    if (!online || !physical) {
      if (online && !physical) q = q.where('modes.online', isEqualTo: true);
      if (physical && !online) q = q.where('modes.physical', isEqualTo: true);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.limit(50).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No eligible helpers found for this category.'));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final u = doc.data();
            final name = (u['displayName'] ?? u['name'] ?? doc.id).toString();
            final bio = (u['bio'] ?? '').toString();
            final city = (u['city'] ?? '').toString();
            final rating = (u['rating'] ?? 0).toString();
            final modes = (u['modes'] ?? {}) as Map<String, dynamic>;
            final tags = <String>[
              if (modes['online'] == true) 'Online',
              if (modes['physical'] == true) 'Physical',
              if (city.isNotEmpty) city,
              '⭐ $rating',
            ];

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(name),
              subtitle: Text([bio, if (tags.isNotEmpty) tags.join(' • ')].where((s) => s != null && s.toString().trim().isNotEmpty).join('\n')),
              isThreeLine: bio.trim().isNotEmpty,
              trailing: ElevatedButton(
                onPressed: () => onInvite(doc.id, categoryId),
                child: const Text('Invite'),
              ),
            );
          },
        );
      },
    );
  }
}
