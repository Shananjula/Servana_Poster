// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:servana/l10n/i18n.dart';
import 'package:servana/screens/notifications_screen.dart';
import 'package:servana/screens/browse_screen.dart';
import 'package:servana/screens/post_task_screen.dart';
import 'package:servana/screens/my_posts_screen.dart';
import 'package:servana/screens/helper_public_profile_screen.dart';
import 'package:servana/screens/map_view_screen.dart'; // full map page
import 'package:servana/screens/top_up_screen.dart';   // wallet shortcut

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Home-level filter state we carry into Browse
  String _mode = 'Physical'; // or 'Online'
  bool _openNow = false;

  void _openBrowse({String? initialCategory}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BrowseScreen(initialCategory: initialCategory),
        settings: RouteSettings(
          name: 'Browse',
          arguments: {'serviceMode': _mode, 'openNow': _openNow},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t(context, 'SERVANA'),
            style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Greeting line
          const _GreetingLine(),
          const SizedBox(height: 10),

          // Big hero
          Text(
            t(context, 'Find help, fast'),
            style:
            const TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            t(context, 'Post a task or browse trusted helpers'),
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
          ),

          const SizedBox(height: 16),
          _QuickActionsRow(
            onPost: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PostTaskScreen()),
            ),
            onBrowse: () => _openBrowse(),
            onWallet: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TopUpScreen()),
            ),
            onMyPosts: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyPostsScreen()),
            ),
          ),

          const SizedBox(height: 18),
          const _MiniMapCard(),

          const SizedBox(height: 14),
          // Swappable categories
          _CategoryChips(
            onPick: (label) => _openBrowse(initialCategory: label),
          ),

          // Online/Physical toggle + "Open now"
          const SizedBox(height: 10),
          Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Physical', label: Text('Physical')),
                  ButtonSegment(value: 'Online', label: Text('Online')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const Spacer(),
              FilterChip(
                label: const Text('Open now'),
                selected: _openNow,
                onSelected: (v) => setState(() => _openNow = v),
              ),
            ],
          ),

          const SizedBox(height: 18),
          _SectionHeader(
            title: t(context, 'Recommended for you'),
            onSeeAll: () => _openBrowse(),
          ),
          const SizedBox(height: 8),
          const _RecommendedHelpers(),

          const SizedBox(height: 18),
          _SectionHeader(
            title: t(context, 'My recent posts'),
            onSeeAll: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyPostsScreen()),
            ),
          ),
          const SizedBox(height: 8),
          const _MyRecentPostsRow(),
        ],
      ),
    );
  }
}

/// ===== Greeting =====
class _GreetingLine extends StatelessWidget {
  const _GreetingLine();

  String _greetingForHour(int h) {
    if (h >= 5 && h < 12) return 'Good morning ☀️';
    if (h >= 12 && h < 17) return 'Good afternoon 🌤️';
    if (h >= 17 && h < 22) return 'Good evening 🌙';
    return 'Hello 👋';
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final base = _greetingForHour(hour);

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      final name = user.displayName!.trim();
      return Text(
        '$base, $name',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      );
    }

    if (uid == null) {
      return Text(
        '$base',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      );
    }

    final doc = FirebaseFirestore.instance.collection('users').doc(uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: doc.snapshots(),
      builder: (context, snap) {
        final name = (snap.data?.data()?['displayName'] ?? '').toString().trim();
        final who = name.isEmpty ? 'there' : name;
        return Text(
          '$base, $who',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        );
      },
    );
  }
}

/// ===== Quick actions =====
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onPost,
    required this.onBrowse,
    required this.onWallet,
    required this.onMyPosts,
  });

  final VoidCallback onPost;
  final VoidCallback onBrowse;
  final VoidCallback onWallet;
  final VoidCallback onMyPosts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionTile(icon: Icons.post_add_rounded, label: t(context, 'Post'), onTap: onPost),
        const SizedBox(width: 12),
        _ActionTile(icon: Icons.people_rounded, label: t(context, 'Browse'), onTap: onBrowse),
        const SizedBox(width: 12),
        _ActionTile(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Wallet',
            onTap: onWallet),
        const SizedBox(width: 12),
        _ActionTile(
            icon: Icons.list_alt_rounded, label: 'My posts', onTap: onMyPosts),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          height: 92,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outline.withOpacity(0.12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===== Mini-map card =====
class _MiniMapCard extends StatelessWidget {
  const _MiniMapCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MapViewScreen()),
      ),
      child: Ink(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: cs.surface,
          border: Border.all(color: cs.outline.withOpacity(0.12)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.surfaceVariant, cs.surface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: cs.outline.withOpacity(0.12)),
                ),
                child: const Text('Helpers near you',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  _pill(context, '2 km'),
                  const SizedBox(width: 8),
                  _pill(context, '5 km'),
                  const SizedBox(width: 8),
                  _pill(context, '10 km'),
                  const Spacer(),
                  _pill(context, 'All', icon: Icons.tune_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String text, {IconData? icon}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// ===== Category chips (swipeable) =====
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.onPick});
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const cats = <(String, IconData)>[
      ('Plumbing', Icons.plumbing_rounded),
      ('Cleaning', Icons.cleaning_services_rounded),
      ('Tutoring', Icons.menu_book_rounded),
      ('Electrical', Icons.electric_bolt_rounded),
      ('Painting', Icons.format_paint_rounded),
      ('Delivery', Icons.delivery_dining_rounded),
      ('Repairs', Icons.build_rounded),
      ('AC Service', Icons.ac_unit_rounded),
      ('Gardening', Icons.yard_rounded),
      ('IT Support', Icons.phonelink_setup_rounded),
      ('Moving', Icons.local_shipping_rounded),
      ('Carpentry', Icons.handyman_rounded),
    ];

    Color tintFor(String label) {
      final k = label.toLowerCase();
      if (k.contains('plumb')) return Colors.blue;
      if (k.contains('clean')) return Colors.teal;
      if (k.contains('tutor')) return Colors.indigo;
      if (k.contains('elect')) return Colors.amber;
      if (k.contains('paint')) return Colors.purple;
      if (k.contains('deliver')) return Colors.orange;
      if (k.contains('repair') || k.contains('carp')) return Colors.brown;
      if (k.contains('ac')) return Colors.cyan;
      if (k.contains('garden')) return Colors.green;
      if (k.contains('it')) return Colors.deepPurple;
      if (k.contains('mov')) return Colors.deepOrange;
      return cs.primary;
    }

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (label, icon) = cats[i];
          final tint = tintFor(label);
          return GestureDetector(
            onTap: () => onPick(label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: cs.outline.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                      color: tint.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: tint),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ===== Recommended helpers =====
class _RecommendedHelpers extends StatelessWidget {
  const _RecommendedHelpers();

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('users')
        .where('isHelper', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(8)
        .snapshots();

    return SizedBox(
      height: 160,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q,
        builder: (context, snap) {
          if (!snap.hasData) {
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => _helperSkeleton(context),
            );
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return _emptyCard(context, 'No recommendations yet');
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final h = docs[i].data();
              final name = (h['displayName'] ?? 'Helper').toString();
              final tag = (h['tagline'] ?? 'Popular in your area').toString();
              final id = docs[i].id;
              return _HelperCardMini(
                name: name,
                subtitle: tag,
                onProfile: () => Navigator.of(ctx).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          HelperPublicProfileScreen(helperId: id)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _helperSkeleton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
    );
  }

  Widget _emptyCard(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 140,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Text(text),
    );
  }
}

class _HelperCardMini extends StatelessWidget {
  const _HelperCardMini(
      {required this.name, required this.subtitle, required this.onProfile});
  final String name;
  final String subtitle;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurfaceVariant)),
          const Spacer(),
          TextButton.icon(
              onPressed: onProfile,
              icon: const Icon(Icons.person_rounded),
              label: const Text('View profile')),
        ],
      ),
    );
  }
}

/// ===== My posts =====
class _MyRecentPostsRow extends StatelessWidget {
  const _MyRecentPostsRow();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cs = Theme.of(context).colorScheme;

    final stream = uid == null
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
        .collection('tasks')
        .where('posterId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(6)
        .snapshots();

    return SizedBox(
      height: 130,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => Container(
                width: 220,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border:
                  Border.all(color: cs.outline.withOpacity(0.12)),
                ),
              ),
            );
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withOpacity(0.12)),
              ),
              child: const Text('You have no posts yet.'),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final t = docs[i].data();
              final title = (t['title'] ?? 'Untitled').toString();
              final status = (t['status'] ?? 'open').toString();
              return Container(
                width: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outline.withOpacity(0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Chip(
                        label: Text(status),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                            color: cs.outline.withOpacity(0.12)),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});
  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900))),
        TextButton(onPressed: onSeeAll, child: Text(t(context, 'See all'))),
      ],
    );
  }
}
