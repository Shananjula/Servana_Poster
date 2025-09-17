// lib/screens/profile_screen.dart — Poster app
// Adds "Invite helper" CTA that calls the inviteHelper callable and shows
// the required fee note text near the button.
//
// Where this belongs:
//   Poster repo already navigates to ProfileScreen(userId: helper.id) from helper listings.
//   This screen extends that profile with an Invite button for posters.
//
// Button copy (as requested):
//   Text('Invite helper — costs 50 coins if this is your first contact with them.')
//
// Callable:
//   FirebaseFunctions.instance.httpsCallable('inviteHelper')
//     .call({'helperId': helperId, 'taskId': taskId, 'categoryId': categoryId});
//
// Notes:
// - If taskId/categoryId are not provided via constructor/route args, a small bottom sheet
//   will prompt for them before calling the function.
// - This keeps dependencies minimal (Firestore/Auth/Functions), so it should drop in even
//   if the app doesn’t use Provider on this screen yet.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.userId, // whose profile to show (helper or poster). If null => current user
    this.preselectTaskId,
    this.preselectCategoryId,
  });

  final String? userId;
  final String? preselectTaskId;
  final String? preselectCategoryId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;
  String? _taskIdOverride;
  String? _categoryIdOverride;

  String get _viewerUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> _userRefFor(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  Future<void> _inviteHelperFlow({
    required String helperId,
    String? taskId,
    String? categoryId,
  }) async {
    // If missing info, prompt once.
    final t = taskId ?? _taskIdOverride ?? widget.preselectTaskId;
    final c = categoryId ?? _categoryIdOverride ?? widget.preselectCategoryId;

    String? finalTaskId = t;
    String? finalCategoryId = c;

    if (finalTaskId == null || finalCategoryId == null) {
      final result = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _TaskCategoryPickerSheet(
          initialTaskId: finalTaskId,
          initialCategoryId: finalCategoryId,
        ),
      );
      if (result == null) return;
      finalTaskId = result['taskId'];
      finalCategoryId = result['categoryId'];
    }

    if (finalTaskId == null || finalCategoryId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both task and category.')),
      );
      return;
    }

    await _inviteHelper(
      helperId: helperId,
      taskId: finalTaskId!,
      categoryId: finalCategoryId!,
    );
  }

  Future<void> _inviteHelper({
    required String helperId,
    required String taskId,
    required String categoryId,
  }) async {
    setState(() => _busy = true);
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('inviteHelper')
          .call({'helperId': helperId, 'taskId': taskId, 'categoryId': categoryId});

      final data = res.data;
      final msg = data is Map && data['message'] != null
          ? data['message'].toString()
          : (data?.toString() ?? 'Invite sent.');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite failed: ${e.code} — ${e.message ?? 'Unknown error'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String viewedUid = widget.userId ?? _viewerUid;
    final bool isSelf = viewedUid == _viewerUid;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userRefFor(viewedUid).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final m = snap.data?.data() ?? const <String, dynamic>{};
          final name = (m['displayName'] ?? m['name'] ?? 'User') as String;
          final photoURL = (m['photoURL'] ?? '') as String;
          final isHelper = (m['isHelper'] == true) ||
              ((m['roles'] is Map) && (m['roles']['helper'] == true));
          final isVerified = (m['verificationStatus'] == 'verified') ||
              (m['isVerified'] == true);
          final rating = (m['averageRating'] is num) ? (m['averageRating'] as num).toDouble() : null;
          final jobs = (m['jobs'] is num) ? (m['jobs'] as num).toInt() : null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: (photoURL.isNotEmpty) ? NetworkImage(photoURL) : null,
                    child: photoURL.isEmpty ? const Icon(Icons.person, size: 36) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (isHelper) const Chip(label: Text('Helper')),
                            if (isVerified) const Chip(label: Text('Verified')),
                            if (rating != null)
                              Chip(
                                label: Text('★ ${rating.toStringAsFixed(1)}'),
                              ),
                            if (jobs != null) Chip(label: Text('$jobs jobs')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              if (!isSelf && isHelper) ...[
                // Fee note near the button (as requested)
                const Text(
                  'Invite helper — costs 50 coins if this is your first contact with them.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _inviteHelperFlow(helperId: viewedUid),
                        icon: const Icon(Icons.mail_outline),
                        label: _busy
                            ? const Text('Inviting...')
                            : const Text('Invite helper'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  isSelf
                      ? 'This is your profile.'
                      : 'This user is not a helper.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 24),
              // You can add more profile sections below (about, portfolio, reviews, etc.).
            ],
          );
        },
      ),
    );
  }
}

class _TaskCategoryPickerSheet extends StatefulWidget {
  const _TaskCategoryPickerSheet({
    this.initialTaskId,
    this.initialCategoryId,
  });

  final String? initialTaskId;
  final String? initialCategoryId;

  @override
  State<_TaskCategoryPickerSheet> createState() => _TaskCategoryPickerSheetState();
}

class _TaskCategoryPickerSheetState extends State<_TaskCategoryPickerSheet> {
  final _taskCtrl = TextEditingController();
  final _catCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _taskCtrl.text = widget.initialTaskId ?? '';
    _catCtrl.text = widget.initialCategoryId ?? '';
  }

  @override
  void dispose() {
    _taskCtrl.dispose();
    _catCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invite details', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _taskCtrl,
            decoration: const InputDecoration(
              labelText: 'Task ID',
              hintText: 'tasks/{taskId} document id',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _catCtrl,
            decoration: const InputDecoration(
              labelText: 'Category ID',
              hintText: 'e.g. tutoring_english, cleaning_house, ...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final t = _taskCtrl.text.trim();
                    final c = _catCtrl.text.trim();
                    if (t.isEmpty || c.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Both task and category are required.')),
                      );
                      return;
                    }
                    Navigator.of(context).pop({'taskId': t, 'categoryId': c});
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
