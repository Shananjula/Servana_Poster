import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HelperPublicProfileScreen extends StatefulWidget {
  final String helperId;

  const HelperPublicProfileScreen({Key? key, required this.helperId}) : super(key: key);

  @override
  State<HelperPublicProfileScreen> createState() => _HelperPublicProfileScreenState();
}

class _HelperPublicProfileScreenState extends State<HelperPublicProfileScreen> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _helperFuture;

  @override
  void initState() {
    super.initState();
    _helperFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.helperId)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Helper Profile'),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _helperFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Error fetching helper profile: ${snapshot.error}");
            return Center(child: Text('Error loading profile: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Helper profile not found.'));
          }

          final helperData = snapshot.data!.data();
          // FIX: Used correct field names 'displayName' and 'photoURL' from the user_model.
          final String helperName = helperData?['displayName'] ?? 'Helper Name';
          final String helperAvatarUrl = helperData?['photoURL'] ?? '';
          final String helperBio = helperData?['bio'] ?? 'No bio available.';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                CircleAvatar(
                  radius: 50,
                  backgroundImage: helperAvatarUrl.isNotEmpty ? NetworkImage(helperAvatarUrl) : null,
                  child: helperAvatarUrl.isEmpty ? const Icon(Icons.person, size: 50) : null,
                ),
                const SizedBox(height: 16),
                Text(
                  helperName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Helper ID: ${widget.helperId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About Me',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(helperBio, style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.message_outlined),
                  label: const Text('Contact Helper'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contact functionality not implemented yet.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
