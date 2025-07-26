import 'package:flutter/material.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/screens/helper_public_profile_screen.dart';

class HelperCard extends StatelessWidget {
  final HelpifyUser helper;

  const HelperCard({super.key, required this.helper});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HelperPublicProfileScreen(helperId: helper.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundImage: helper.photoURL != null && helper.photoURL!.isNotEmpty ? NetworkImage(helper.photoURL!) : null,
                child: helper.photoURL == null || helper.photoURL!.isEmpty ? const Icon(Icons.person, size: 30) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      helper.displayName ?? 'Helpify Helper',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (helper.skills.isNotEmpty)
                      Text(
                        helper.skills.join(', '),
                        style: TextStyle(color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber[600], size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${helper.averageRating.toStringAsFixed(1)} (${helper.ratingCount} reviews)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
