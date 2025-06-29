import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

// Import your centralized models
import '../models/task_model.dart';
import '../models/user_model.dart';

// Import other screens for navigation
import 'rating_screen.dart';

// --- The Dynamic Active Task Screen ---
class ActiveTaskScreen extends StatelessWidget {
  final Task initialTask;

  const ActiveTaskScreen({Key? key, required this.initialTask}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This outer StreamBuilder ensures the whole screen reacts to status changes
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('tasks').doc(initialTask.id).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || !snapshot.data!.exists || snapshot.error != null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text("Error loading task details.")));
        }

        final task = Task.fromFirestore(snapshot.data!);

        return Scaffold(
          appBar: AppBar(title: Text(task.title)),
          body: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _buildContentForStatus(context, task),
                ),
              ),
              _buildBottomBarForStatus(context, task),
            ],
          ),
        );
      },
    );
  }

  // --- Widget Switcher Logic ---
  Widget _buildContentForStatus(BuildContext context, Task task) {
    switch (task.status) {
      case 'assigned':
        return HelperOnTheWayView(key: ValueKey(task.id), task: task);
      case 'in_progress':
        return TaskInProgressView(key: const ValueKey('in_progress'), task: task);
      case 'finished':
        return TaskFinishedView(key: const ValueKey('finished'), task: task);
      case 'completed':
        return TaskCompletedView(key: const ValueKey('completed'), task: task);
      case 'cancelled':
        return TaskCancelledView(key: const ValueKey('cancelled'), task: task);
      default:
        return Center(child: Text("Current task status: ${task.status}"));
    }
  }

  // --- UPDATED: Main logic for displaying the correct action bar ---
  Widget _buildBottomBarForStatus(BuildContext context, Task task) {
    final bool isPoster = FirebaseAuth.instance.currentUser?.uid == task.posterId;

    // Logic for the Poster
    if (isPoster) {
      switch (task.status) {
        case 'assigned':
          return _buildDigitalHandshakeBar(context, task);
        case 'in_progress':
          return _buildCancelTaskBar(context, task);
        case 'finished':
        // Here we check the payment method to decide which button to show
          if (task.paymentMethod == 'cash') {
            return _buildConfirmCashPaymentBar(context, task);
          } else {
            // For 'escrow' payments, this would lead to a payment release screen
            // For now, it will navigate to the rating screen directly for simplicity.
            return _buildPaymentBar(context, task);
          }
        default:
          return const SizedBox.shrink();
      }
    }
    // Logic for the Helper
    else {
      switch (task.status) {
        case 'in_progress':
          return _buildMarkAsFinishedBar(context, task);
        default:
          return const SizedBox.shrink();
      }
    }
  }

  // --- Bottom Action Bar Builders ---

  // For the Poster when Helper is on the way
  Widget _buildDigitalHandshakeBar(BuildContext context, Task task) {
    return Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        color: Colors.white,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.handshake_outlined),
          label: const Text("Confirm Helper's Arrival"),
          onPressed: () => FirebaseFirestore.instance.collection('tasks').doc(task.id).update({'status': 'in_progress'}),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ));
  }

  // For the Poster when task is in progress
  Widget _buildCancelTaskBar(BuildContext context, Task task) {
    return Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        color: Colors.white,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.cancel_outlined),
          label: const Text("Cancel Task"),
          onPressed: () => showDialog(context: context, builder: (ctx) => CancellationDialog(task: task)),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ));
  }

  // For the Helper when task is in progress
  Widget _buildMarkAsFinishedBar(BuildContext context, Task task) {
    return Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        color: Colors.white,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text("Mark Task as Finished"),
          onPressed: () => FirebaseFirestore.instance.collection('tasks').doc(task.id).update({'status': 'finished'}),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ));
  }

  // --- NEW: Action bar for Poster to confirm cash payment ---
  Widget _buildConfirmCashPaymentBar(BuildContext context, Task task) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "The helper has marked this task as finished. Please confirm you have paid them in cash.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Mark the task as completed and navigate both users to rating screen
              _completeTaskAndRate(context, task);
            },
            child: const Text("I Have Paid in Cash"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )
        ],
      ),
    );
  }

  // For Poster, for Escrow payments
  Widget _buildPaymentBar(BuildContext context, Task task) {
    return Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Task is complete! Please release the payment and rate your helper.", textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
                child: const Text("Release Payment & Rate"),
                onPressed: () => _completeTaskAndRate(context, task), // For now, this directly completes the task
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))
          ],
        ));
  }

  // --- Helper function to complete the task and navigate to rating ---
  Future<void> _completeTaskAndRate(BuildContext context, Task task) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // In a real app, this would be a cloud function triggered after payment release.
    // For now, we update the status directly.
    await FirebaseFirestore.instance.collection('tasks').doc(task.id).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });

    // Determine who to rate
    String personToRateId;
    String personToRateName;
    String? personToRateAvatarUrl;

    if (currentUser.uid == task.posterId) {
      personToRateId = task.assignedHelperId ?? '';
      personToRateName = task.assignedHelperName ?? 'Helper';
      personToRateAvatarUrl = task.assignedHelperAvatarUrl;
    } else {
      // This case is for the helper, who would see the rating screen after Poster pays.
      personToRateId = task.posterId;
      personToRateName = task.posterName;
      personToRateAvatarUrl = task.posterAvatarUrl;
    }

    if (personToRateId.isEmpty) return;

    // Navigate to the rating screen
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (ctx) => RatingScreen(
      task: task,
      personToRateId: personToRateId,
      personToRateName: personToRateName,
      personToRateAvatarUrl: personToRateAvatarUrl,
    )));
  }
}


// --- Status-Specific Views (No changes needed below this line) ---
class HelperOnTheWayView extends StatefulWidget {
  final Task task;
  const HelperOnTheWayView({Key? key, required this.task}) : super(key: key);
  @override
  _HelperOnTheWayViewState createState() => _HelperOnTheWayViewState();
}
class _HelperOnTheWayViewState extends State<HelperOnTheWayView> {
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};
  @override
  void initState() {
    super.initState();
    _updateMarkers(widget.task);
  }
  @override
  void didUpdateWidget(covariant HelperOnTheWayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.helperLastLocation != oldWidget.task.helperLastLocation) {
      _updateMarkers(widget.task);
      _updateCameraPosition(widget.task);
    }
  }
  void _updateMarkers(Task task) {
    final Set<Marker> markers = {};
    if (task.location != null) {
      markers.add(Marker(
        markerId: const MarkerId('task_destination'),
        position: LatLng(task.location!.latitude, task.location!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Task Location'),
      ));
    }
    if (task.helperLastLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('helper_location'),
        position: LatLng(task.helperLastLocation!.latitude, task.helperLastLocation!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: '${task.assignedHelperName ?? 'Helper'} is here'),
      ));
    }
    if(mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }
  Future<void> _updateCameraPosition(Task task) async {
    final controller = await _mapController.future;
    final taskLocation = task.location;
    final helperLocation = task.helperLastLocation;
    if (taskLocation != null && helperLocation != null) {
      controller.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            taskLocation.latitude < helperLocation.latitude ? taskLocation.latitude : helperLocation.latitude,
            taskLocation.longitude < helperLocation.longitude ? taskLocation.longitude : helperLocation.longitude,
          ),
          northeast: LatLng(
            taskLocation.latitude > helperLocation.latitude ? taskLocation.latitude : helperLocation.latitude,
            taskLocation.longitude > helperLocation.longitude ? taskLocation.longitude : helperLocation.longitude,
          ),
        ),
        100.0,
      ));
    } else if (taskLocation != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(taskLocation.latitude, taskLocation.longitude), 15));
    }
  }
  @override
  Widget build(BuildContext context) {
    final initialCamPosition = widget.task.location != null
        ? CameraPosition(target: LatLng(widget.task.location!.latitude, widget.task.location!.longitude), zoom: 14)
        : const CameraPosition(target: LatLng(6.9271, 79.8612), zoom: 11);
    return GoogleMap(
      key: ValueKey(widget.task.id),
      mapType: MapType.normal,
      initialCameraPosition: initialCamPosition,
      markers: _markers,
      onMapCreated: (GoogleMapController controller) {
        if (!_mapController.isCompleted) {
          _mapController.complete(controller);
          _updateCameraPosition(widget.task);
        }
      },
    );
  }
}
class TaskInProgressView extends StatelessWidget {
  final Task task;
  const TaskInProgressView({Key? key, required this.task}) : super(key: key);
  @override
  Widget build(BuildContext context) => Center(child: Text("Task in progress: '${task.title}'", textAlign: TextAlign.center));
}
class TaskFinishedView extends StatelessWidget {
  final Task task;
  const TaskFinishedView({Key? key, required this.task}) : super(key: key);
  @override
  Widget build(BuildContext context) => Center(child: Text("Task finished: '${task.title}'! Awaiting your action.", textAlign: TextAlign.center));
}
class TaskCompletedView extends StatelessWidget {
  final Task task;
  const TaskCompletedView({Key? key, required this.task}) : super(key: key);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24.0),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: Colors.green[700]),
          const SizedBox(height: 24),
          const Text("Task Completed!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}
class TaskCancelledView extends StatelessWidget {
  final Task task;
  const TaskCancelledView({Key? key, required this.task}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, size: 80, color: Colors.red[700]),
            const SizedBox(height: 24),
            const Text("Task Cancelled", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text("This task was cancelled by the ${task.cancelledBy ?? 'user'}.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            if (task.cancellationReason != null && task.cancellationReason!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text("Reason: ${task.cancellationReason}", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }
}
class CancellationDialog extends StatefulWidget {
  final Task task;
  const CancellationDialog({Key? key, required this.task}) : super(key: key);
  @override
  _CancellationDialogState createState() => _CancellationDialogState();
}
class _CancellationDialogState extends State<CancellationDialog> {
  String? _selectedReason;
  final _otherReasonController = TextEditingController();
  final List<String> _reasons = ["Helper is not the right fit for the job", "Helper is late or unresponsive", "I made a mistake in the task details", "I no longer need this task done", "Other"];
  bool _isSubmitting = false;
  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }
  Future<void> _submitCancellation() async {
    if (_selectedReason == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSubmitting = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final currentUser = HelpifyUser.fromFirestore(userDoc);
      if (currentUser.cancellationCount >= 5) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You have reached your cancellation limit."), backgroundColor: Colors.red));
        if (mounted) Navigator.of(context).pop();
        return;
      }
      String finalReason = _selectedReason!;
      if (_selectedReason == "Other") {
        finalReason = _otherReasonController.text.trim().isEmpty ? "Other" : _otherReasonController.text.trim();
      }
      final batch = FirebaseFirestore.instance.batch();
      final taskRef = FirebaseFirestore.instance.collection('tasks').doc(widget.task.id);
      batch.update(taskRef, {'status': 'cancelled', 'cancellationReason': finalReason, 'cancelledBy': 'poster'});
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.update(userRef, {'cancellationCount': FieldValue.increment(1)});
      await batch.commit();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      print("Error cancelling task: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to cancel task."), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Reason for Cancellation"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._reasons.map((reason) => RadioListTile<String>(
              title: Text(reason),
              value: reason,
              groupValue: _selectedReason,
              onChanged: (value) => setState(() => _selectedReason = value),
            )),
            if (_selectedReason == "Other")
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
                child: TextField(
                  controller: _otherReasonController,
                  decoration: const InputDecoration(hintText: "Please specify your reason..."),
                  autofocus: true,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Back")),
        ElevatedButton(
          onPressed: (_selectedReason == null || _isSubmitting) ? null : _submitCancellation,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Confirm Cancellation"),
        )
      ],
    );
  }
}

