import 'package:servana/utils/analytics.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
// lib/widgets/helper_card.dart
//
// HelperCard — decision-at-a-glance + actions
// - Hero row: avatar, name, primary category, distance/ETA (if available)
// - Rating strip: ★ 4.8 (213) + 98% on-time + Top Rated badge
// - Price cue: From LKR 2,500 or LKR 1,500/hr + invoice tag
// - Fact chips: Verified ID • 5+ yrs • English/Sinhala • Pet-friendly • Tools included
// - Actions: Contact (CTA), View profile, Save (heart)
//
// Data shape is tolerant; provide as much as you have in `data`.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/widgets/quick_contact_sheet.dart';
import 'package:servana/screens/helper_public_profile_screen.dart';

class HelperCard extends StatefulWidget {
  const HelperCard({super.key, required this.data, this.onViewProfile});
  final Map<String, dynamic> data;
  final VoidCallback? onViewProfile;

  @override
  State<HelperCard> createState() => _HelperCardState();
}

class _HelperCardState extends State<HelperCard> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final hid = widget.data['id'];
      final doc = await FirebaseFirestore.instance.collection('shortlists').doc(uid).collection('helpers').doc(hid).get();
      if (doc.exists) {
        HapticFeedback.selectionClick(); setState(() => _saved = true);
      }
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final hid = widget.data['id'];
      final ref = FirebaseFirestore.instance.collection('shortlists').doc(uid).collection('helpers').doc(hid);
      if (_saved) {
        await ref.delete();
        HapticFeedback.selectionClick(); setState(() => _saved = false);
      } else {
        await ref.set({'savedAt': FieldValue.serverTimestamp(), 'data': widget.data});
        HapticFeedback.selectionClick(); setState(() => _saved = true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = widget.data;
    final name = (h['displayName'] ?? 'Helper').toString();
    final cat = (h['primaryCategory'] ?? (h['categories'] ?? 'General')).toString();
    final rating = (h['rating'] ?? 4.8).toString();
    final reviews = (h['reviewsCount'] ?? 12).toString();
    final onTime = ((h['onTimeRate'] ?? 0.98) * 100).toStringAsFixed(0);
    final topRated = (h['topRated'] ?? false) == true;
    final priceFrom = h['priceFrom'];
    final hourly = h['hourly'] == true;
    final invoice = (h['providesInvoice'] ?? true) == true;
    final distText = h['distanceText'] ?? '—';
    final etaText = h['etaText'] ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 26, child: h['photoUrl'] == null ? const Icon(Icons.person) : null, backgroundImage: h['photoUrl'] == null ? null : CachedNetworkImageProvider(h['photoUrl'])),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                        IconButton(
                          tooltip: _saved ? 'Saved' : 'Save',
                          onPressed: () { Analytics.log(_saved ? 'shortlist_remove' : 'shortlist_save', params: {'helperId': h['id']}); _toggleSave(); },
                          icon: Icon(_saved ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                        ),
                      ],
                    ),
                    Text(cat, style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.place_rounded, size: 16),
                        const SizedBox(width: 4),
                        Text(distText),
                        if ((etaText as String).isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.timer_rounded, size: 16),
                          const SizedBox(width: 4),
                          Text(etaText),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 18),
              const SizedBox(width: 4),
              Text('$rating ($reviews)'),
              const SizedBox(width: 12),
              const Icon(Icons.bolt_rounded, size: 18),
              const SizedBox(width: 4),
              Text('$onTime% on-time'),
              const SizedBox(width: 12),
              if (topRated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Top Rated', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (priceFrom != null)
                Text(
                  hourly ? 'LKR $priceFrom/hr' : 'From LKR $priceFrom',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              const Spacer(),
              if (invoice)
                Row(children: const [
                  Icon(Icons.receipt_long_rounded, size: 16),
                  SizedBox(width: 4),
                  Text('Invoice available'),
                ]),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if ((h['verifiedId'] ?? true) == true) const Chip(label: Text('Verified ID')),
              if ((h['years'] ?? 3) != null) Chip(label: Text('${h['years'] ?? 3}+ yrs')),
              const Chip(label: Text('English/Sinhala')), // placeholder — localize
              if ((h['petFriendly'] ?? false) == true) const Chip(label: Text('Pet-friendly')),
              if ((h['bringsTools'] ?? false) == true) const Chip(label: Text('Tools included')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: const Text('Contact'),
                  onPressed: () { Analytics.log('contact_click', params: {'helperId': h['id'], 'helperName': name}); showQuickContactSheet(
                    context,
                    helperId: h['id'] ?? '',
                    helperName: name,
                  ); },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_rounded),
                label: const Text('View profile'),
                onPressed: widget.onViewProfile ?? () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HelperPublicProfileScreen(helperId: h['id']))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
