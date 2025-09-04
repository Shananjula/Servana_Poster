// lib/screens/poster_dashboard_screen.dart
//
// Poster Dashboard (role-aware; no role switching UI here)
// • Quick actions (IconTile grid): Post task / Browse helpers / Wallet / My posts
// • MiniMapCard(mode: 'poster') to preview nearby helpers
// • Recommended helpers (horizontal strip; tolerant of missing fields)
// • My recent posts (StatusChip + AmountPill; safe fallbacks)
// • Tapping the map opens full MapViewScreen
//
// Invariants kept:
// - No role toggle here (Profile is the only place to switch modes).
// - Additive only; does not rename exported classes or routes.
// - Uses UserProvider as the single source of truth.

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:servana/providers/user_provider.dart';

// Widgets (new shared components)
import 'package:servana/widgets/icon_tile.dart';
import 'package:servana/widgets/status_chip.dart';
import 'package:servana/widgets/amount_pill.dart';
import 'package:servana/widgets/mini_map_card.dart';

// Destinations
import 'package:servana/screens/post_task_screen.dart';
import 'package:servana/screens/browse_screen.dart';
import 'package:servana/screens/wallet_screen.dart';
import 'package:servana/screens/my_posts_screen.dart';
import 'package:servana/screens/map_view_screen.dart';
import 'package:servana/screens/task_details_screen.dart';
import 'package:servana/screens/helper_public_profile_screen.dart';

class PosterDashboardScreen extends StatelessWidget {
  const PosterDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final userProv = context.watch<UserProvider>();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Hero header (concise, scalable)
            _HeroHeader(
              title: 'Find help, fast',
              subtitle: userProv.isHelperMode
                  ? 'You are in Helper mode — switch in Profile to post tasks'
                  : 'Post a task or browse trusted helpers',
            ),

            const SizedBox(height: 12),

            // Quick actions grid (IconTile)
            _QuickActionsGrid(
              onPostTask: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostTaskScreen()),
              ),
              onBrowseHelpers: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrowseScreen()),
              ),
              onWallet: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              ),
              onMyPosts: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyPostsScreen()),
              ),
            ),

            const SizedBox(height: 16),

            // Mini map (poster -> show helpers)
            Text('Nearby helpers', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            MiniMapCard(
              mode: 'poster',
              onOpenFull: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MapViewScreen()));
              },
            ),

            const SizedBox(height: 16),

            // Recommended helpers
            _SectionHeader(
              title: 'Recommended for you',
              actionLabel: 'See all',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrowseScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _RecommendedHelpersStrip(centerResolver: _centerFromUserDoc),

            const SizedBox(height: 16),

            // My recent posts
            _SectionHeader(
              title: 'My recent posts',
              actionLabel: 'See all',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyPostsScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _MyPostsList(),
          ],
        ),
      ),
      backgroundColor: cs.surface,
    );
  }
}

// -------------------------------
// HERO
// -------------------------------
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    )),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Decorative icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.handshake_rounded, color: cs.primary),
          ),
        ],
      ),
    );
  }
}

// -------------------------------
// QUICK ACTIONS
// -------------------------------
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onPostTask,
    required this.onBrowseHelpers,
    required this.onWallet,
    required this.onMyPosts,
  });

  final VoidCallback onPostTask;
  final VoidCallback onBrowseHelpers;
  final VoidCallback onWallet;
  final VoidCallback onMyPosts;

  @override
  Widget build(BuildContext context) {
    // 4 tiles across on most phones; IconTile ensures ≥ 88x96 tap targets
    return LayoutBuilder(
      builder: (context, constraints) {
        final cross = constraints.maxWidth >= 720 ? 6 : 4;
        return GridView.count(
          crossAxisCount: cross,
  childAspectRatio: cross >= 6 ? 1.0 : 0.75,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            IconTile(icon: Icons.post_add_rounded, label: 'Post task', onTap: onPostTask),
            IconTile(icon: Icons.people_alt_rounded, label: 'Browse helpers', onTap: onBrowseHelpers),
            IconTile(icon: Icons.account_balance_wallet_rounded, label: 'Wallet', onTap: onWallet),
            IconTile(icon: Icons.list_alt_rounded, label: 'My posts', onTap: onMyPosts),
          ],
        );
      },
    );
  }
}

// -------------------------------
// RECOMMENDED HELPERS (H strip)
// -------------------------------
class _RecommendedHelpersStrip extends StatelessWidget {
  const _RecommendedHelpersStrip({required this.centerResolver});

  final Future<LatLng?> Function() centerResolver;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<LatLng?>(
      future: centerResolver(),
      builder: (context, centerSnap) {
        final center = centerSnap.data;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('isHelper', isEqualTo: true)
              .limit(24)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 130,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return _EmptyStrip(message: 'No recommendations yet');
            }

            // Basic heuristic sort: live first, then higher rating, then nearer (if we have a center)
            final list = docs.where((d) => d.id != uid).toList();
            list.sort((a, b) {
              final pa = a.data();
              final pb = b.data();

              final la = (pa['presence'] is Map<String, dynamic>) && (pa['presence']['isLive'] == true);
              final lb = (pb['presence'] is Map<String, dynamic>) && (pb['presence']['isLive'] == true);
              if (la != lb) return lb ? 1 : -1; // live first

              final ra = (pa['ratingAvg'] is num) ? (pa['ratingAvg'] as num).toDouble() : 0.0;
              final rb = (pb['ratingAvg'] is num) ? (pb['ratingAvg'] as num).toDouble() : 0.0;
              if (ra != rb) return rb.compareTo(ra); // higher rating first

              if (center != null) {
                final da = _distanceKm(center, _posFromUser(pa) ?? center);
                final db = _distanceKm(center, _posFromUser(pb) ?? center);
                return da.compareTo(db); // nearer first
              }
              return 0;
            });

            return SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final d = list[i];
                  final data = d.data();

                  final name = (data['displayName'] as String?)?.trim().isNotEmpty == true
                      ? (data['displayName'] as String).trim()
                      : 'Helper';
                  final live = (data['presence'] is Map<String, dynamic>) && data['presence']['isLive'] == true;
                  final rating = (data['ratingAvg'] is num) ? (data['ratingAvg'] as num).toDouble() : null;

                  // Why recommended: server-provided, else heuristic
                  String why = (data['whyRecommended'] as String?)?.trim() ?? '';
                  if (why.isEmpty) {
                    if (live) {
                      final dist = center == null ? null : _distanceKm(center, _posFromUser(data) ?? center);
                      why = dist != null ? 'Live • ${dist.toStringAsFixed(1)} km' : 'Live now';
                    } else if (rating != null && rating >= 4.7) {
                      why = 'Top rated';
                    } else {
                      why = 'Popular in your area';
                    }
                  }

                  return _HelperCardMini(
                    name: name,
                    id: d.id,
                    live: live,
                    rating: rating,
                    why: why,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HelperPublicProfileScreen(helperId: d.id),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // Helpers
  LatLng? _posFromUser(Map<String, dynamic> data) {
    GeoPoint? gp;
    final presence =
    (data['presence'] is Map<String, dynamic>) ? data['presence'] as Map<String, dynamic> : null;
    if (presence?['currentLocation'] is GeoPoint) {
      gp = presence!['currentLocation'] as GeoPoint;
    } else if (data['workLocation'] is GeoPoint) {
      gp = data['workLocation'] as GeoPoint;
    } else if (data['homeLocation'] is GeoPoint) {
      gp = data['homeLocation'] as GeoPoint;
    }
    if (gp == null) return null;
    return LatLng(gp.latitude, gp.longitude);
  }

  double _distanceKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = _deg2rad(b.lat - a.lat);
    final dLon = _deg2rad(b.lng - a.lng);
    final lat1 = _deg2rad(a.lat);
    final lat2 = _deg2rad(b.lat);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return R * c;
  }

  double _deg2rad(double d) => d * (math.pi / 180.0);
}

class _HelperCardMini extends StatelessWidget {
  const _HelperCardMini({
    required this.name,
    required this.id,
    required this.live,
    required this.why,
    this.rating,
    this.onTap,
  });

  final String name;
  final String id;
  final bool live;
  final String why;
  final double? rating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + live chip / rating
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 6),
                if (rating != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rate_rounded, size: 16),
                      Text(rating!.toStringAsFixed(1), style: theme.textTheme.labelSmall),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: live ? cs.primary : cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    live ? 'Live' : '—',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: live ? cs.onPrimary : theme.textTheme.labelSmall?.color,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    why,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.person_search_rounded, size: 18),
                label: const Text('View profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStrip extends StatelessWidget {
  const _EmptyStrip({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Text(message),
    );
  }
}

// -------------------------------
// MY RECENT POSTS
// -------------------------------
class _MyPostsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return _EmptyStrip(message: 'Sign in to view your posts');
    }

    Query<Map<String, dynamic>> q =
    FirebaseFirestore.instance.collection('tasks').where('posterId', isEqualTo: uid);
    // Prefer newest first if index exists
    try {
      q = q.orderBy('createdAt', descending: true);
    } catch (_) {
      // Fallback: leave unordered
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.limit(10).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingList(height: 180);
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return _EmptyStrip(message: 'No posts yet');
        }
        return ListView.separated(
          itemCount: docs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final title = (data['title'] as String?)?.trim().isNotEmpty == true
                ? (data['title'] as String).trim()
                : 'Task';
            final status = (data['status'] as String?) ?? 'open';
            final city = (data['city'] as String?)?.trim() ?? '';
            final createdAt = _asTimestamp(data['createdAt']);
            final budgetText = _bestBudgetText(data);

            return Material(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.12)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: d.id)),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      // Leading icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.work_outline_rounded),
                      ),
                      const SizedBox(width: 12),
                      // Title + meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (city.isNotEmpty) city,
                                if (createdAt != null) _timeAgo(createdAt),
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Trailing: amount + status
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AmountPill(text: budgetText),
                          const SizedBox(height: 6),
                          StatusChip(status),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Timestamp? _asTimestamp(dynamic v) {
    if (v is Timestamp) return v;
    return null;
  }

  String? _bestBudgetText(Map<String, dynamic> task) {
    final num? finalAmount = task['finalAmount'] as num?;
    final num? budget = task['budget'] as num?;
    final num? minB = task['budgetMin'] as num?;
    final num? maxB = task['budgetMax'] as num?;
    if (finalAmount != null) return _formatLkr(finalAmount);
    if (budget != null) return _formatLkr(budget);
    if (minB != null && maxB != null) return '${_formatLkr(minB)}–${_formatLkr(maxB)}';
    if (minB != null) return 'From ${_formatLkr(minB)}';
    if (maxB != null) return 'Up to ${_formatLkr(maxB)}';
    return null;
  }

  String _formatLkr(num n) {
    final negative = n < 0;
    final abs = n.abs();
    final isWhole = abs % 1 == 0;
    final raw = isWhole ? abs.toStringAsFixed(0) : abs.toStringAsFixed(2);
    final parts = raw.split('.');
    String whole = parts[0];
    final frac = parts.length > 1 ? parts[1] : '';
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    whole = whole.replaceAllMapped(reg, (m) => ',');
    final sign = negative ? '−' : '';
    return frac.isEmpty ? 'LKR $sign$whole' : 'LKR $sign$whole.$frac';
  }

  String _timeAgo(Timestamp ts) {
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = (diff.inDays / 7).floor();
    return '${weeks}w ago';
  }
}

// -------------------------------
// UTIL: resolve user-centered LatLng
// -------------------------------
Future<LatLng?> _centerFromUserDoc() async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const LatLng(6.9271, 79.8612); // Colombo
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data();
    if (data == null) return const LatLng(6.9271, 79.8612);

    GeoPoint? gp;
    final presence =
    (data['presence'] is Map<String, dynamic>) ? data['presence'] as Map<String, dynamic> : null;
    if (presence?['currentLocation'] is GeoPoint) {
      gp = presence!['currentLocation'] as GeoPoint;
    } else if (data['workLocation'] is GeoPoint) {
      gp = data['workLocation'] as GeoPoint;
    } else if (data['homeLocation'] is GeoPoint) {
      gp = data['homeLocation'] as GeoPoint;
    }
    if (gp == null) return const LatLng(6.9271, 79.8612);
    return LatLng(gp.latitude, gp.longitude);
  } catch (_) {
    return const LatLng(6.9271, 79.8612);
  }
}

// Lightweight LatLng to avoid extra imports for this file.
class LatLng {
  const LatLng(this.lat, this.lng);
  final double lat;
  final double lng;
}

// Simple loading skeleton
class _LoadingList extends StatelessWidget {
  const _LoadingList({this.height = 120});
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Column(
        children: List.generate(
          3,
              (i) => Container(
            height: 56,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

// Section header with an action
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
