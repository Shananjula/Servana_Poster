import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// *** UPDATED: Importing the centralized Service model ***
import '../models/service_model.dart';
import 'add_edit_service_screen.dart';

// Standalone testing code
void main() {
  runApp(const HelpifyApp());
}

class HelpifyApp extends StatelessWidget {
  const HelpifyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helpify',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Poppins',
      ),
      home: const ManageServicesScreen(),
    );
  }
}

// --- The Main Screen Widget ---
class ManageServicesScreen extends StatefulWidget {
  const ManageServicesScreen({Key? key}) : super(key: key);

  @override
  State<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen> {

  void _addService() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditServiceScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please log in.")));
    }

    // Query to get services created by the current user
    // Assumes services are stored under /users/{userId}/services/
    final myServicesQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('services');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Offered Services'),
      ),
      // *** UPDATED: Using a StreamBuilder to display live services ***
      body: StreamBuilder<QuerySnapshot>(
        stream: myServicesQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load your services.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('You have not offered any services yet.'));
          }

          final services = snapshot.data!.docs
              .map((doc) => Service.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>, null))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return ServiceCard(service: service);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addService,
        icon: const Icon(Icons.add),
        label: const Text('Add Service'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}

// --- Service Card Widget ---
class ServiceCard extends StatelessWidget {
  final Service service;

  const ServiceCard({Key? key, required this.service}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(service.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text('LKR ${service.rate.toStringAsFixed(0)} ${service.rateType}', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => AddEditServiceScreen(service: service)));
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Status:', style: TextStyle(color: Colors.grey[600])),
                  Row(
                    children: [
                      Text(service.isActive ? 'Active' : 'Paused', style: TextStyle(color: service.isActive ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                      Switch(
                        value: service.isActive,
                        onChanged: (value) {
                          // TODO: Update 'isActive' field in Firestore
                        },
                        activeColor: Colors.teal,
                      ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
