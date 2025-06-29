import 'package:flutter/material.dart';
import 'package:helpify/models/task_model.dart';
import 'package:helpify/screens/task_details_screen.dart';
import 'package:intl/intl.dart';

class RecommendedTaskCard extends StatelessWidget {
  final Task task;

  const RecommendedTaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 240,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsScreen(task: task))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if(task.imageUrl != null && task.imageUrl!.isNotEmpty)
                Image.network(task.imageUrl!, height: 90, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, o, s) => _buildPlaceholder(theme))
              else
                _buildPlaceholder(theme),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(task.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('LKR ${NumberFormat("#,##0").format(task.budget)}', style: theme.textTheme.titleMedium?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(height: 90, color: theme.colorScheme.secondaryContainer, child: Center(child: Icon(Icons.work_outline, color: Colors.white.withOpacity(0.8), size: 40,)));
  }
}
