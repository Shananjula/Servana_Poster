// lib/screens/activity_screen.dart
//
// ActivityScreen (Poster)
// Segments: Offers → Ongoing → Cancel → Disputes → Booked → Completed
// AppBar action: Notifications + Filter (Online / Physical)
// The filter is client-side tolerant: checks task['mode'/'serviceMode'] or flags like isOnline.
//
// NOTE: Wire into your PosterHomeShell tabs.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:servana/screens/task_details_screen.dart';
import 'package:servana/screens/dispute_center_screen.dart';
import 'package:servana/screens/notifications_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _mode = 'Physical'; // or 'Online'

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _openFilter() async {
    final newMode = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      showDragHandle: true,
      builder: (_) => _FilterSheet(mode: _mode),
    );
    if (newMode != null && mounted) {
      setState(() => _mode = newMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Filter',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openFilter,
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12.0),
              tabs: const [
                Tab(text: 'Offers'),
                Tab(text: 'Ongoing'),
                Tab(text: 'Cancel'),
                Tab(text: 'Disputes'),
                Tab(text: 'Booked'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OffersTab(mode: _mode),
          _OngoingTab(mode: _mode),
          _CancelTab(mode: _mode),
          _DisputesTab(mode: _mode),
          _BookedTab(mode: _mode),
          _CompletedTab(mode: _mode),
        ],
      ),
    );
  }
}

// =========== Tabs ===========

class _OffersTab extends StatelessWidget {
  const _OffersTab({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    return _TasksStreamList(
      titleEmpty: 'No offers yet',
      statuses: const ['offer', 'offer_received', 'offer_pending'],
      extraCollection: 'offers', // tolerant fallback
      emptyHint:
      'When helpers respond to your tasks with prices or counters, they show up here.',
      tileBuilder: (ctx, data, id) => _OfferTile(data: data, docId: id),
      mode: mode,
    );
  }
}

class _OngoingTab extends StatelessWidget {
  const _OngoingTab({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    return _TasksStreamList(
      titleEmpty: 'No ongoing jobs',
      statuses: const ['en_route', 'arrived', 'in_progress', 'started', 'ongoing'],
      emptyHint:
      'Accepted jobs that have started appear here. Open details to track progress.',
      mode: mode,
    );
  }
}

class _CancelTab extends StatelessWidget {
  const _CancelTab({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    return _TasksStreamList(
      titleEmpty: 'No cancelled jobs',
      statuses: const ['cancelled', 'canceled'],
      emptyHint: 'Cancelled jobs will show here with reason and refund outcome.',
      mode: mode,
    );
  }
}

class _DisputesTab extends StatelessWidget {
  const _DisputesTab({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    return _TasksStreamList(
      titleEmpty: 'No disputes',
      statuses: const ['disputed', 'in_dispute'],
      whereDisputeFlag: true,
      emptyHint: 'Active disputes and their status will appear here.',
      tileBuilder: (ctx, data, id) => _DisputeTile(data: data, docId: id),
      mode: mode,
    );
  }
}

class _BookedTab extends StatelessWidget {
  const _BookedTab({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    return _TasksStreamList(
      titleEmpty: 'No bookings scheduled',
      statuses: const ['booked', 'scheduled'],
      emptyHint:
      'Jobs you’ve accepted with a scheduled time will be listed here.',
      mode: mode,
    );
  }
}

class _CompletedTab extends StatelessWidget {
  const _CompletedTab({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    return _TasksStreamList(
      titleEmpty: 'No completed jobs yet',
      statuses: const ['completed', 'done', 'finished'],
      emptyHint: 'Once a job is finished, rate and review from here.',
      mode: mode,
    );
  }
}

// =========== List + Query Layer ===========

typedef TaskTileBuilder = Widget Function(
    BuildContext context, Map<String, dynamic> data, String docId);

class _TasksStreamList extends StatelessWidget {
  const _TasksStreamList({
    required this.titleEmpty,
    required this.statuses,
    required this.mode,
    this.whereDisputeFlag = false,
    this.extraCollection,
    this.emptyHint,
    this.tileBuilder,
  });

  final String titleEmpty;
  final List<String> statuses;
  final String mode; // 'Online' | 'Physical'
  final bool whereDisputeFlag;
  final String? extraCollection;
  final String? emptyHint;
  final TaskTileBuilder? tileBuilder;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _EmptyState(
          title: 'Not signed in', hint: 'Sign in to see your activity.');
    }

    final tasksQuery = _safeTasksQuery(uid, statuses, whereDisputeFlag);
    final extraQuery =
    extraCollection == null ? null : _safeExtraQuery(uid, extraCollection!);

    return StreamBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
      stream: _mergedSnapshots([
        tasksQuery?.snapshots(),
        extraQuery?.snapshots(),
      ].whereType<Stream<QuerySnapshot<Map<String, dynamic>>>>().toList()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _LoadingListSkeleton();
        }

        // Flatten results from tasks + optional offers
        final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        for (final qs in snapshot.data!) {
          allDocs.addAll(qs.docs);
        }

        // De-dupe by ID
        final map = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final d in allDocs) {
          map[d.id] = d;
        }
        var docs = map.values.toList();

        if (docs.isEmpty) {
          return _EmptyState(title: titleEmpty, hint: emptyHint);
        }

        // Sort by updatedAt/createdAt desc if present
        docs.sort((a, b) {
          final ad = a.data();
          final bd = b.data();
          final aTs = (ad['updatedAt'] ?? ad['createdAt']);
          final bTs = (bd['updatedAt'] ?? bd['createdAt']);
          final aMillis = _toMillis(aTs);
          final bMillis = _toMillis(bTs);
          return bMillis.compareTo(aMillis);
        });

        // Client-side filter by mode (tolerant)
        final filtered = docs.where((doc) {
          final t = doc.data();
          return _matchMode(t, mode);
        }).toList();

        if (filtered.isEmpty) {
          return _EmptyState(
              title: 'No matching items',
              hint: 'Try switching between Online and Physical.');
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final doc = filtered[i];
            final data = doc.data();
            final builder = tileBuilder ?? _DefaultTaskTile.new;
            return builder(ctx, data, doc.id);
          },
        );
      },
    );
  }

  // Firestore query (tolerant)
  Query<Map<String, dynamic>>? _safeTasksQuery(
      String uid, List<String> statuses, bool dispute) {
    try {
      var q = FirebaseFirestore.instance
          .collection('tasks')
          .where('posterId', isEqualTo: uid);
      if (statuses.isNotEmpty) {
        q = q.where('status', whereIn: statuses);
      }
      q = q.orderBy('updatedAt', descending: true);
      return q;
    } catch (_) {
      try {
        var q = FirebaseFirestore.instance
            .collection('tasks')
            .where('posterId', isEqualTo: uid)
            .orderBy('createdAt', descending: true);
        return q;
      } catch (_) {
        return null;
      }
    }
  }

  // Optional extra collection (e.g., offers)
  Query<Map<String, dynamic>>? _safeExtraQuery(String uid, String collection) {
    try {
      var q = FirebaseFirestore.instance
          .collection(collection)
          .where('posterId', isEqualTo: uid)
          .orderBy('updatedAt', descending: true);
      return q;
    } catch (_) {
      try {
        return FirebaseFirestore.instance
            .collection(collection)
            .where('posterId', isEqualTo: uid)
            .orderBy('createdAt', descending: true);
      } catch (_) {
        return null;
      }
    }
  }
}

// Combine multiple query streams (simple combineLatest)
Stream<List<QuerySnapshot<Map<String, dynamic>>>> _mergedSnapshots(
    List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams) async* {
  if (streams.isEmpty) {
    yield <QuerySnapshot<Map<String, dynamic>>>[];
    return;
  }
  final latest =
  List<QuerySnapshot<Map<String, dynamic>>?>.filled(streams.length, null);
  final controller =
  StreamController<List<QuerySnapshot<Map<String, dynamic>>>>();
  final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

  for (var i = 0; i < streams.length; i++) {
    final s = streams[i].listen((qs) {
      latest[i] = qs;
      if (latest.every((e) => e != null)) {
        controller
            .add(latest.whereType<QuerySnapshot<Map<String, dynamic>>>().toList());
      }
    }, onError: controller.addError);
    subs.add(s);
  }

  yield* controller.stream;

  await controller.close();
  for (final s in subs) {
    await s.cancel();
  }
}

// Mode matcher (tolerant): 'mode'/'serviceMode' strings or booleans like isOnline
bool _matchMode(Map<String, dynamic> t, String mode) {
  final raw = (t['mode'] ?? t['serviceMode'] ?? t['type'] ?? '')
      .toString()
      .toLowerCase();
  final onlineFlag =
      (t['isOnline'] == true) || (t['online'] == true) || raw.contains('online');
  final physicalFlag = raw.contains('physical') ||
      raw.contains('onsite') ||
      raw.contains('on-site') ||
      (t['isPhysical'] == true);

  if (mode == 'Online') {
    if (onlineFlag) return true;
    // Unknown mode → include (avoid hiding items missing field)
    return !(physicalFlag);
  } else {
    // Physical
    if (physicalFlag) return true;
    return !(onlineFlag);
  }
}

// =========== Tiles ===========

class _DefaultTaskTile extends StatelessWidget {
  const _DefaultTaskTile(this.context, this.data, this.docId);
  final BuildContext context;
  final Map<String, dynamic> data;
  final String docId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = (data['title'] ?? 'Task').toString();
    final status = (data['status'] ?? data['state'] ?? 'unknown').toString();
    final subtitle =
    (data['locationText'] ?? data['category'] ?? '').toString();

    return InkWell(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: docId))),
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assignment_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusPill(status: status),
          ],
        ),
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.data, required this.docId});
  final Map<String, dynamic> data;
  final String docId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = (data['title'] ?? data['taskTitle'] ?? 'Offer').toString();
    final helper = (data['helperName'] ?? data['helperId'] ?? 'Helper').toString();
    final price = data['price'] ?? data['amount'];
    final priceText = price == null ? '' : 'LKR $price';

    return InkWell(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: docId))),
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_offer_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(helper,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (priceText.isNotEmpty)
                  Text(priceText,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: docId))),
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Review offer'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: docId))),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Accept / Counter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DisputeTile extends StatelessWidget {
  const _DisputeTile({required this.data, required this.docId});
  final Map<String, dynamic> data;
  final String docId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = (data['title'] ?? 'Dispute').toString();
    final status = (data['dispute']?['status'] ?? 'under_review').toString();

    return InkWell(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DisputeCenterScreen())),
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.report_problem_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Dispute • $status',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

// =========== UI Helpers ===========

// Simple empty-state widget used in Activity tabs.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = status.toLowerCase();
    Color bg = cs.surfaceVariant, fg = cs.onSurfaceVariant;
    if (t.contains('offer')) {
      bg = cs.secondaryContainer;
      fg = cs.onSecondaryContainer;
    } else if (t.contains('route') ||
        t.contains('progress') ||
        t.contains('ongoing') ||
        t.contains('start')) {
      bg = cs.primaryContainer;
      fg = cs.onPrimaryContainer;
    } else if (t.contains('book')) {
      bg = cs.tertiaryContainer;
      fg = cs.onTertiaryContainer;
    } else if (t.contains('complete') ||
        t.contains('done') ||
        t.contains('finish')) {
      bg = Colors.green.withOpacity(0.18);
      fg = Colors.green.shade900;
    } else if (t.contains('cancel')) {
      bg = cs.errorContainer;
      fg = cs.onErrorContainer;
    } else if (t.contains('disput')) {
      bg = Colors.orange.withOpacity(0.18);
      fg = Colors.orange.shade900;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child:
      Text(status, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _LoadingListSkeleton extends StatelessWidget {
  const _LoadingListSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => Container(
        height: 76,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.12)),
        ),
      ),
    );
  }
}

int _toMillis(dynamic ts) {
  if (ts == null) return 0;
  if (ts is int) return ts;
  if (ts is Timestamp) return ts.millisecondsSinceEpoch;
  if (ts is DateTime) return ts.millisecondsSinceEpoch;
  try {
    return int.parse(ts.toString());
  } catch (_) {
    return 0;
  }
}

// =========== Filter Sheet ===========

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.mode});
  final String mode;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter activity',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Text('Mode', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Physical', label: Text('Physical')),
              ButtonSegment(value: 'Online', label: Text('Online')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _mode),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}