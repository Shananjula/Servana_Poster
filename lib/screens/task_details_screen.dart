import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:servana/models/user_model.dart';
import 'package:intl/intl.dart';
import 'package:servana/providers/user_provider.dart';
import 'package:servana/services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/task_model.dart';
import 'helper_public_profile_screen.dart';


class TaskDetailsScreen extends StatefulWidget {
  final Task task;
  const TaskDetailsScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  String? _distanceInKm;
  String? _estimatedTime;
  bool _isCalculating = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.task.taskType == 'physical') {
      _calculateDistanceAndTime();
    } else {
      setState(() => _isCalculating = false);
    }
  }

  Future<void> _calculateDistanceAndTime() async {
    try {
      if (widget.task.location == null) {
        if(mounted) setState(() => _isCalculating = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.task.location!.latitude,
        widget.task.location!.longitude,
      );
      final distanceKm = distanceInMeters / 1000;
      final averageSpeedKmh = 25;
      final timeHours = distanceKm / averageSpeedKmh;
      final timeMinutes = timeHours * 60;
      if(mounted) {
        setState(() {
          _distanceInKm = distanceKm.toStringAsFixed(1);
          _estimatedTime = timeMinutes.toStringAsFixed(0);
          _isCalculating = false;
        });
      }
    } catch (e) {
      if(mounted) setState(() => _isCalculating = false);
    }
  }

  Future<void> _launchMapsNavigation() async {
    if (widget.task.location == null) return;
    final lat = widget.task.location!.latitude;
    final lng = widget.task.location!.longitude;
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  // --- MODIFIED: Uses the new FirestoreService ---
  Future<void> _startNegotiation({required double offerAmount, String? message}) async {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in.')));
      return;
    }

    setState(() => _isSubmitting = true);

    await FirestoreService().initiateOfferAndNavigateToChat(
      context: context,
      task: widget.task,
      helper: user,
      offerAmount: offerAmount,
      initialMessage: message,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final taskLatLng = LatLng(widget.task.location?.latitude ?? 6.9271, widget.task.location?.longitude ?? 79.8612);
    final String fullCategory = '${widget.task.category}${widget.task.subCategory != null ? " > ${widget.task.subCategory}" : ""}';
    final bool isOnlineTask = widget.task.taskType == 'online';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                  fullCategory,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black45)])
              ),
              background: isOnlineTask
                  ? _buildOnlineTaskHeader()
                  : GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: CameraPosition(target: taskLatLng, zoom: 14),
                markers: { Marker(markerId: const MarkerId('taskLocation'), position: taskLatLng) },
                onMapCreated: (controller) { if (!_mapController.isCompleted) _mapController.complete(controller); },
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.task.title, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    _buildPaymentInfoCard(context, widget.task.paymentMethod),
                    const SizedBox(height: 16),
                    _buildPosterInfoCard(context),
                    const SizedBox(height: 24),
                    if (!isOnlineTask)
                      _buildLocationDetailsSection(context)
                    else
                      _buildOnlineTaskSection(context),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Task Details'),
                    const SizedBox(height: 8),
                    Text(widget.task.description, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // --- UI HELPER WIDGETS ---

  Widget _buildOnlineTaskHeader() {
    return Image.network(
      widget.task.imageUrl ?? 'https://placehold.co/600x400/1e40af/white?text=Online+Task',
      fit: BoxFit.cover,
      color: Colors.black.withOpacity(0.4),
      colorBlendMode: BlendMode.darken,
      errorBuilder: (context, error, stackTrace) {
        return Container(
            color: Colors.blue.shade800,
            child: const Center(child: Icon(Icons.language, color: Colors.white54, size: 80))
        );
      },
    );
  }

  Widget _buildOnlineTaskSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Task Type'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(Icons.language, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              const Text('This is an online/remote task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentInfoCard(BuildContext context, String paymentMethod) {
    final isCash = paymentMethod == 'cash';
    final theme = Theme.of(context);
    final icon = isCash ? Icons.money_outlined : Icons.shield_outlined;
    final text = isCash ? 'Pay with Cash' : 'Secure Escrow Payment';
    final subtext = isCash
        ? 'Payment is made directly to the Helper upon completion.'
        : 'Payment is held by Helpify and released upon completion.';
    final color = isCash ? Colors.orange.shade700 : theme.primaryColor;

    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtext, style: theme.textTheme.bodySmall?.copyWith(color: color.withOpacity(0.9))),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDetailsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Location'),
        const SizedBox(height: 8),
        Text(widget.task.locationAddress ?? 'Address not available', style: const TextStyle(fontSize: 16, color: Colors.black87)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.teal.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip(context, Icons.directions_car, _isCalculating ? "..." : "${_distanceInKm ?? 'N/A'} km", "Distance"),
              _buildStatChip(context, Icons.timer_outlined, _isCalculating ? "..." : "~${_estimatedTime ?? 'N/A'} min", "Est. Time"),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _launchMapsNavigation,
          icon: const Icon(Icons.navigation_outlined),
          label: const Text('Get Directions'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
        )
      ],
    );
  }

  Widget _buildStatChip(BuildContext context, IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black));
  }

  Widget _buildPosterInfoCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[200],
              backgroundImage: widget.task.posterAvatarUrl != null && widget.task.posterAvatarUrl!.isNotEmpty ? NetworkImage(widget.task.posterAvatarUrl!) : null,
              child: widget.task.posterAvatarUrl == null || widget.task.posterAvatarUrl!.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Posted by ${widget.task.posterName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Theme.of(context).primaryColor, size: 18),
                      const SizedBox(width: 4),
                      Text('Trust Score: ${widget.task.posterTrustScore ?? 'N/A'}/10', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final isMyTask = FirebaseAuth.instance.currentUser?.uid == widget.task.posterId;
    if (widget.task.status != 'open' || isMyTask) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 8)]),
      child: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (context) => _MakeOfferView(
                      task: widget.task,
                      onSubmit: (double amount, String? message) {
                        _startNegotiation(offerAmount: amount, message: message);
                      }),
                );
              },
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Make an Offer'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                _startNegotiation(offerAmount: widget.task.budget);
              },
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Accept for LKR ${NumberFormat("#,##0").format(widget.task.budget)}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MakeOfferView extends StatefulWidget {
  final Task task;
  final Function(double amount, String? message) onSubmit;

  const _MakeOfferView({Key? key, required this.task, required this.onSubmit}) : super(key: key);
  @override
  State<_MakeOfferView> createState() => __MakeOfferViewState();
}

class __MakeOfferViewState extends State<_MakeOfferView> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context);
    widget.onSubmit(
      double.parse(_amountController.text),
      _messageController.text.trim().isNotEmpty ? _messageController.text.trim() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Make Your Offer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Poster\'s budget is LKR ${widget.task.budget.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Your Offer Amount', prefixText: 'LKR ', border: OutlineInputBorder()),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter an amount';
                if (double.tryParse(value) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _messageController,
              decoration: const InputDecoration(labelText: 'Optional Message to Poster', hintText: 'e.g., "I can start right away!"', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ).copyWith(backgroundColor: MaterialStateProperty.all(Theme.of(context).primaryColor)),
              child: const Text('Submit Offer & Chat', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
