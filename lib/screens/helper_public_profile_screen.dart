import 'package:cached_network_image/cached_network_image.dart';
// lib/screens/helper_public_profile_screen.dart
//
// Helper Public Profile (Poster-facing)
// - Big hero, badges, about, services, portfolio, ratings, availability
// - Sticky actions: Contact • Book • Share
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:servana/l10n/i18n.dart';
import 'package:servana/widgets/quick_contact_sheet.dart';
import 'package:servana/widgets/booking_sheet.dart';

class HelperPublicProfileScreen extends StatelessWidget {
  const HelperPublicProfileScreen({super.key, required this.helperId});
  final String helperId;

  @override
  Widget build(BuildContext context) {
    final doc = FirebaseFirestore.instance.collection('users').doc(helperId);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Helper profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: doc.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final h = snap.data!.data() ?? {};
          final name = (h['displayName'] ?? 'Helper').toString();
          final cats = (h['categories'] ?? h['primaryCategory'] ?? 'General').toString();
          final lastActive = (h['presence']?['lastSeenText'] ?? 'Recently active').toString();
          final reply = (h['replyMins'] ?? 15).toString();
          final rating = (h['rating'] ?? 4.8).toString();
          final reviews = (h['reviewsCount'] ?? 0).toString();
          final priceFrom = (h['priceFrom'] is num) ? (h['priceFrom'] as num).toInt() : null;
          final hourly = (h['hourly'] ?? false) == true;

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  // Hero
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundImage: h['photoUrl'] == null ? null : NetworkImage(h['photoUrl']),
                        child: h['photoUrl'] == null ? const Icon(Icons.person, size: 36) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(cats, style: TextStyle(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              children: [
                                Row(children: [const Icon(Icons.access_time_rounded, size: 16), const SizedBox(width: 4), Text('Replies ~${reply}m')]),
                                Row(children: [const Icon(Icons.visibility_rounded, size: 16), const SizedBox(width: 4), Text(lastActive)]),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Badges
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      if ((h['verifiedId'] ?? true) == true) const Chip(label: Text('Verified ID'), avatar: Icon(Icons.verified_rounded, size: 18)),
                      if ((h['proHelper'] ?? false) == true) const Chip(label: Text('Pro Helper'), avatar: Icon(Icons.workspace_premium_rounded, size: 18)),
                      if ((h['docsChecked'] ?? true) == true) const Chip(label: Text('Docs checked'), avatar: Icon(Icons.badge_rounded, size: 18)),
                      if ((h['jobsCount'] ?? 0) > 100) Chip(label: Text('${h['jobsCount']}+ jobs'), avatar: const Icon(Icons.task_alt_rounded, size: 18)),
                      Chip(label: Text('${((h['onTimeRate'] ?? 0.98) * 100).toStringAsFixed(0)}% on-time'), avatar: const Icon(Icons.bolt_rounded, size: 18)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // About & specialties
                  const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text((h['bio'] ?? 'No bio yet.').toString()),
                  const SizedBox(height: 12),
                  const Text('Services & prices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _ServicesList(services: (h['services'] ?? []) as List? ?? const []),
                  const SizedBox(height: 16),
                  // Portfolio
                  const Text('Portfolio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _Portfolio(images: (h['portfolio'] ?? []) as List? ?? const []),
                  const SizedBox(height: 16),
                  // Ratings
                  const Text('Ratings & reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded),
                      const SizedBox(width: 4),
                      Text('$rating ($reviews)'),
                      const SizedBox(width: 12),
                      Wrap(spacing: 6, children: const [
                        Chip(label: Text('polite')), Chip(label: Text('punctual')), Chip(label: Text('neat')),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Availability (placeholder)
                  const Text('Availability', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Container(
                    height: 56,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withOpacity(0.12)),
                    ),
                    child: const Text('Next 7 days — calendar integration coming soon'),
                  ),
                ],
              ),
              // Sticky actions
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(top: BorderSide(color: cs.outline.withOpacity(0.12))),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.chat_bubble_rounded),
                          label: Text(t(context, 'Contact')),
                          onPressed: () => showQuickContactSheet(context, helperId: helperId, helperName: name),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.event_available_rounded),
                          label: Text(t(context, 'Book')),
                          onPressed: () => showBookingSheet(
                            context,
                            helperId: helperId,
                            helperName: name,
                            category: cats,
                            priceFrom: priceFrom,
                            hourly: hourly,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Share'),
                        onPressed: () {
                          // TODO: implement deep link sharing
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ServicesList extends StatelessWidget {
  const _ServicesList({required this.services});
  final List services;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const Text('No service list provided.');
    }
    return Column(
      children: [
        for (final s in services.take(6))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.design_services_rounded),
            title: Text((s['name'] ?? 'Service').toString()),
            subtitle: Text((s['desc'] ?? '').toString()),
            trailing: Text(
              s['hourly'] == true ? 'LKR ${s['price']}/hr' : 'From LKR ${s['price']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _Portfolio extends StatelessWidget {
  const _Portfolio({required this.images});
  final List images;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (images.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.12)),
        ),
        child: const Text('No portfolio yet.'),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final url = images[i];
          return GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(imageUrl: url, width: 160, height: 120, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(
                width: 160, height: 120,
                color: cs.surface,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_rounded),
              )),
            ),
          );
        },
      ),
    );
  }
}
