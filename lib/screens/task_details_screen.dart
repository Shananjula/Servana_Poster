import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:helpify/models/user_model.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/task_model.dart';
import '../models/offer_model.dart';
import 'active_task_screen.dart';
import 'helper_active_task_screen.dart';
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
  bool _isAccepting = false;

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
    // ... (This function remains unchanged)
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
    // ... (This function remains unchanged)
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

  Future<void> _acceptTaskInstantly() async {
    // ... (This function remains unchanged)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in.')));
      return;
    }

    setState(() => _isAccepting = true);

    try {
      final helperDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final taskDocRef = FirebaseFirestore.instance.collection('tasks').doc(widget.task.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final helperSnapshot = await transaction.get(helperDocRef);
        final taskSnapshot = await transaction.get(taskDocRef);

        if (!helperSnapshot.exists) throw Exception('Your user profile could not be found.');
        if (!taskSnapshot.exists || taskSnapshot.data()?['status'] != 'open') throw Exception('This task is no longer available.');

        final helper = HelpifyUser.fromFirestore(helperSnapshot);
        final task = Task.fromFirestore(taskSnapshot);

        final settingsDoc = await transaction.get(FirebaseFirestore.instance.collection("platform_settings").doc("config"));
        final settingsData = settingsDoc.data() ?? {};
        final freeTasksLimit = (settingsData['defaultFreeTasksForHelper'] as int? ?? 5) + helper.bonusTasksAvailable;
        final bool hasFreeTasks = helper.commissionFreeTasksCompleted < freeTasksLimit;

        double commissionAmount = 0;
        if (!task.isCommissionFree && !hasFreeTasks) {
          commissionAmount = task.budget * (settingsData['helperCommissionRate'] as double? ?? 0.075);
        }

        final totalBalance = helper.coinWalletBalance + helper.creditCoinBalance;
        if (totalBalance < commissionAmount) {
          throw Exception('Insufficient coins. Please top up your wallet to accept this task.');
        }

        final confirm = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Acceptance'),
            content: Text(commissionAmount > 0
                ? 'A commission of ${commissionAmount.toStringAsFixed(2)} Coins will be deducted. Proceed?'
                : 'You are accepting this task for LKR ${NumberFormat("#,##0").format(widget.task.budget)}. Proceed?'),
            actions: [
              TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(ctx).pop(false)),
              ElevatedButton(child: const Text('Accept'), onPressed: () => Navigator.of(ctx).pop(true)),
            ],
          ),
        );

        if (confirm != true) throw Exception('Acceptance cancelled by user.');

        double newCoinBalance = helper.coinWalletBalance;
        double newCreditBalance = helper.creditCoinBalance;
        if (commissionAmount > 0) {
          if (newCoinBalance >= commissionAmount) {
            newCoinBalance -= commissionAmount;
          } else {
            final remainingCommission = commissionAmount - newCoinBalance;
            newCoinBalance = 0;
            newCreditBalance -= remainingCommission;
          }
        }

        int newFreeTasksCompleted = helper.commissionFreeTasksCompleted;
        if (hasFreeTasks) {
          newFreeTasksCompleted++;
        }

        transaction.update(helperDocRef, {
          'coinWalletBalance': newCoinBalance,
          'creditCoinBalance': newCreditBalance,
          'commissionFreeTasksCompleted': newFreeTasksCompleted,
        });

        transaction.update(taskDocRef, {
          'status': 'assigned',
          'assignedHelperId': helper.id,
          'assignedHelperName': helper.displayName ?? 'Helpify Helper',
          'assignedHelperAvatarUrl': helper.photoURL ?? '',
          'finalAmount': task.budget,
          'assignmentTimestamp': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task accepted! You can now start.'), backgroundColor: Colors.green),
        );
        final updatedTaskDoc = await taskDocRef.get();
        final updatedTask = Task.fromFirestore(updatedTaskDoc);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (ctx) => HelperActiveTaskScreen(task: updatedTask)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskLatLng = LatLng(widget.task.location?.latitude ?? 6.9271, widget.task.location?.longitude ?? 79.8612);
    // MODIFIED: Create a combined category string to include sub-category
    final String fullCategory = '${widget.task.category}${widget.task.subCategory != null ? " > ${widget.task.subCategory}" : ""}';
    final bool isOnlineTask = widget.task.taskType == 'online';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              // MODIFIED: Use the new fullCategory string
              title: Text(
                  fullCategory,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black45)])
              ),
              background: isOnlineTask
                  ? _buildOnlineTaskHeader() // MODIFIED: Show image for online tasks
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
                    // MODIFIED: Conditionally show location or online task banner
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
      widget.task.imageUrl ?? 'https://placehold.co/600x400/1e40af/white?text=Online+Task', // Placeholder
      fit: BoxFit.cover,
      color: Colors.black.withOpacity(0.4), // Darken the image to make text readable
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

  // All other _build methods remain unchanged from your original file...
  Widget _buildPaymentInfoCard(BuildContext context, String paymentMethod) { /* Unchanged */
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

  Widget _buildLocationDetailsSection(BuildContext context) { /* Unchanged */
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

  Widget _buildStatChip(BuildContext context, IconData icon, String value, String label) { /* Unchanged */
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) { /* Unchanged */
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black));
  }

  Widget _buildPosterInfoCard(BuildContext context) { /* Unchanged */
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

  Widget _buildBottomBar(BuildContext context) { /* Unchanged */
    final isMyTask = FirebaseAuth.instance.currentUser?.uid == widget.task.posterId;
    if (widget.task.status != 'open' || isMyTask) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 8)]),
      child: _isAccepting
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
                  builder: (context) => _MakeOfferView(task: widget.task),
                );
              },
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Make an Offer'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _acceptTaskInstantly,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Accept for LKR ${NumberFormat("#,##0").format(widget.task.budget)}'),
            ),
          ),
        ],
      ),
    );
  }
}

// _MakeOfferView widget remains unchanged
class _MakeOfferView extends StatefulWidget {
  final Task task;
  const _MakeOfferView({Key? key, required this.task}) : super(key: key);
  @override
  State<_MakeOfferView> createState() => __MakeOfferViewState();
}
class __MakeOfferViewState extends State<_MakeOfferView> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }
  Future<void> _submitOffer() async { /* Unchanged */
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to make an offer.')));
      setState(() => _isLoading = false);
      return;
    }
    try {
      final helperDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!helperDoc.exists) throw Exception('Could not find your user profile.');
      final helperData = HelpifyUser.fromFirestore(helperDoc);

      final offersCollection = FirebaseFirestore.instance.collection('tasks').doc(widget.task.id).collection('offers');
      await offersCollection.add({
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'message': _messageController.text,
        'helperId': user.uid,
        'helperName': user.displayName ?? 'Anonymous Helper',
        'helperAvatarUrl': user.photoURL ?? '',
        'helperTrustScore': helperData.averageRating.round(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your offer has been sent!'), backgroundColor: Colors.green));
    } catch (e) {
      print("Failed to submit offer: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send offer. Please try again.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) { /* Unchanged */
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
              onPressed: _isLoading ? null : _submitOffer,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ).copyWith(backgroundColor: MaterialStateProperty.all(Theme.of(context).primaryColor)),
              child: _isLoading ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)) : const Text('Submit Offer', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
