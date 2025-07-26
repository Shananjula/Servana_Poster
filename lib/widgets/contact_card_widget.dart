import 'package:flutter/material.dart';
import 'package:servana/models/task_model.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactCard extends StatelessWidget {
  final Task task;
  final bool isPoster;
  const ContactCard({Key? key, required this.task, required this.isPoster}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hide contact info until the task is confirmed and assigned
    if (task.status == 'open' || task.status == 'negotiating' || task.assignedHelperId == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: Colors.grey),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Contact details will be revealed once a helper is assigned.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- UPDATED LOGIC to display reciprocal contact info ---
    final String name;
    final String? avatarUrl;
    final String? phoneNumber;

    if (isPoster) {
      // If I am the Poster, show the Helper's info
      name = task.assignedHelperName ?? 'Helper';
      avatarUrl = task.assignedHelperAvatarUrl;
      phoneNumber = task.assignedHelperPhoneNumber;
    } else {
      // If I am the Helper, show the Poster's info
      name = task.posterName;
      avatarUrl = task.posterAvatarUrl;
      phoneNumber = task.posterPhoneNumber;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Contact Information", style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isPoster ? "Your Helper" : "Your Poster", style: Theme.of(context).textTheme.bodySmall),
                      Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              // Disable the button if the phone number is not available
              onPressed: (phoneNumber == null || phoneNumber.isEmpty) ? null : () async {
                final url = Uri.parse('tel:$phoneNumber');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not make a call.')));
                }
              },
              icon: const Icon(Icons.call_outlined),
              label: Text('Call $name'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
            ),
            // Show a message if the phone number is missing
            if (phoneNumber == null || phoneNumber.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: Text(
                    'Phone number not provided.',
                    style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
