import 'package:flutter/material.dart';
import 'package:helpify/models/user_model.dart';
import 'package:helpify/screens/profile_screen.dart';

class RecommendedHelperCard extends StatelessWidget {
  final HelpifyUser helper;

  const RecommendedHelperCard({super.key, required this.helper});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: helper.id))),
        child: Container(
            width: 160,
            padding: const EdgeInsets.all(12),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(radius: 35, backgroundImage: helper.photoURL != null ? NetworkImage(helper.photoURL!) : null, child: helper.photoURL == null ? const Icon(Icons.person) : null),
                  const SizedBox(height: 12),
                  Text(helper.displayName ?? '', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if(helper.skills.isNotEmpty)
                    Text(helper.skills.first, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)
                ]
            )
        ),
      ),
    );
  }
}
