import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// --- FIX: Hide the conflicting 'Task' class from firebase_storage ---
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:servana/models/task_model.dart';
import 'package:servana/models/task_modification_model.dart';
import 'package:servana/providers/user_provider.dart';
import 'package:servana/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:servana/widgets/contact_card_widget.dart';
import 'package:servana/widgets/live_location_map_widget.dart';

class ActiveTaskScreen extends StatefulWidget {
  final String taskId;
  const ActiveTaskScreen({Key? key, required this.taskId}) : super(key: key);

  @override
  State<ActiveTaskScreen> createState() => _ActiveTaskScreenState();
}

class _ActiveTaskScreenState extends State<ActiveTaskScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmittingCode = false;
  XFile? _proofImageFile;
  bool _isUploadingProof = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submitConfirmationCode(String taskId) async {
    if (_codeController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter the 4-digit code."), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isSubmittingCode = true);
    try {
      await _firestoreService.helperConfirmsArrivalWithCode(taskId, _codeController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isSubmittingCode = false);
        _codeController.clear();
      }
    }
  }

  Future<void> _uploadProofAndCompleteTask(String taskId) async {
    if (_proofImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a photo as proof."), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isUploadingProof = true);
    try {
      final fileName = '${widget.taskId}_proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('task_proofs').child(fileName);
      await ref.putFile(File(_proofImageFile!.path));
      final imageUrl = await ref.getDownloadURL();
      await _firestoreService.helperCompletesTask(taskId, proofImageUrl: imageUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error uploading proof: ${e.toString()}"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploadingProof = false);
    }
  }

  void _showDisputeDialog(Task task, String currentUserId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report an Issue"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Please describe the issue. Our support team will review this and contact both parties."),
          const SizedBox(height: 16),
          TextField(controller: reasonController, decoration: const InputDecoration(labelText: "Reason for dispute", border: OutlineInputBorder()), maxLines: 3)
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              _firestoreService.initiateDispute(taskId: task.id, reason: reasonController.text.trim(), initiatedByUserId: currentUserId);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Submit Dispute"),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(Task task, String currentUserId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Task"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Are you sure you want to cancel this task? This action cannot be undone."),
          const SizedBox(height: 16),
          TextField(controller: reasonController, decoration: const InputDecoration(labelText: "Reason for cancellation", border: OutlineInputBorder()), maxLines: 2)
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Go Back")),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide a reason.")));
                return;
              }
              _firestoreService.cancelTask(taskId: task.id, reason: reasonController.text.trim(), cancelledById: currentUserId);
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Confirm Cancellation"),
          ),
        ],
      ),
    );
  }

  void _showModificationDialog() {
    final descriptionController = TextEditingController();
    final costController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Request Add-on / Scope Change"),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Describe the additional work and the extra cost required."),
            const SizedBox(height: 16),
            TextFormField(controller: descriptionController, decoration: const InputDecoration(labelText: "Description of extra work", border: OutlineInputBorder()), validator: (val) => val!.isEmpty ? "Description cannot be empty" : null),
            const SizedBox(height: 16),
            TextFormField(
              controller: costController,
              decoration: const InputDecoration(labelText: "Additional Cost (LKR)", border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val!.isEmpty) return "Cost cannot be empty";
                if (double.tryParse(val) == null) return "Invalid number";
                return null;
              },
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _firestoreService.requestTaskModification(taskId: widget.taskId, description: descriptionController.text, additionalCost: double.parse(costController.text));
                Navigator.of(context).pop();
              }
            },
            child: const Text("Submit Request"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: Text("User not found.")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text("Task not found.")));

        final task = Task.fromFirestore(snapshot.data! as DocumentSnapshot<Map<String, dynamic>>);
        final bool isPoster = user.id == task.posterId;
        final List<String> activeStatuses = ['assigned', 'en_route', 'arrived', 'in_progress', 'pending_completion'];
        final bool isTaskActive = activeStatuses.contains(task.status);

        return Scaffold(
          appBar: AppBar(
            title: Text(isPoster ? 'Manage Your Task' : 'Your Active Job'),
            actions: [
              if (isTaskActive)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'dispute') _showDisputeDialog(task, user.id);
                    if (value == 'cancel') _showCancelDialog(task, user.id);
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(value: 'dispute', child: ListTile(leading: Icon(Icons.report_problem_outlined), title: Text('Report an Issue'))),
                    const PopupMenuItem<String>(value: 'cancel', child: ListTile(leading: Icon(Icons.cancel_outlined, color: Colors.red), title: Text('Cancel Task', style: TextStyle(color: Colors.red)))),
                  ],
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _TaskSummaryCard(task: task),
                if (isPoster) _buildModificationsStream(task),
                const SizedBox(height: 20),
                _buildTaskActionFlow(context, task, isPoster),
                const SizedBox(height: 20),
                ContactCard(task: task, isPoster: isPoster),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskActionFlow(BuildContext context, Task task, bool isPoster) {
    switch (task.status) {
      case 'assigned':
        return isPoster ? const _StatusInfoCard(title: 'Waiting for Helper', message: 'The helper has been assigned. They will notify you when they are on their way.', icon: Icons.hourglass_top_rounded) : _ActionCard(title: 'Ready to Go?', message: 'Let the poster know when you start your journey. This will enable live location sharing.', buttonText: 'Start Journey', onPressed: () => _firestoreService.helperStartsJourney(task.id));
      case 'en_route':
        return isPoster ? LiveLocationMap(task: task) : _ActionCard(title: 'Journey Started', message: 'Your location is being shared. When you arrive at the destination, tap the button below.', buttonText: 'I Have Arrived', onPressed: () => _firestoreService.helperArrives(task.id));
      case 'arrived':
        return isPoster ? _ConfirmationCodeCard(code: task.confirmationCode ?? '----') : _EnterCodeCard(controller: _codeController, isLoading: _isSubmittingCode, onSubmit: () => _submitConfirmationCode(task.id));
      case 'in_progress':
        if (isPoster) return const _StatusInfoCard(title: 'Task In Progress', message: 'Your helper is currently working. You will be notified upon completion.', icon: Icons.construction_rounded);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _CompleteTaskCard(
            isLoading: _isUploadingProof,
            imageFile: _proofImageFile,
            onPickImage: () async {
              final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (file != null) setState(() => _proofImageFile = file);
            },
            onComplete: () => _uploadProofAndCompleteTask(task.id),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _showModificationDialog, icon: const Icon(Icons.add_shopping_cart_rounded), label: const Text("Request Add-on / Scope Change"), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), foregroundColor: Theme.of(context).primaryColor))
        ]);
      case 'pending_completion':
        return isPoster ? _ConfirmCompletionCard(task: task, onConfirm: () => _firestoreService.posterConfirmsCompletion(context, task)) : const _StatusInfoCard(title: 'Waiting for Final Confirmation', message: 'The poster has been notified. Payment will be processed upon their confirmation.', icon: Icons.price_check_rounded);
      case 'pending_payment':
      case 'pending_rating':
        return const _StatusInfoCard(title: 'Finalizing Task', message: 'Please follow the prompts to complete payment and leave a rating.', icon: Icons.paid_outlined, color: Colors.green);
      case 'closed':
        return const _StatusInfoCard(title: 'Task Complete!', message: 'This task has been paid, rated, and is now closed. Thank you!', icon: Icons.check_circle_rounded, color: Colors.green);
      case 'in_dispute':
        return const _StatusInfoCard(title: 'Task in Dispute', message: 'An issue has been reported. Our support team will contact you shortly to mediate.', icon: Icons.gavel_rounded, color: Colors.red);
      case 'cancelled':
        return _StatusInfoCard(title: 'Task Cancelled', message: 'This task was cancelled. Reason: ${task.cancellationReason ?? "No reason provided."}', icon: Icons.do_not_disturb_on_outlined, color: Colors.grey);
      default:
        return _StatusInfoCard(title: 'Status: ${task.status}', message: 'The task is in an unknown state.');
    }
  }

  Widget _buildModificationsStream(Task task) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('tasks').doc(task.id).collection('modifications').where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        final modifications = snapshot.data!.docs.map((doc) => TaskModification.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList();
        return Column(
          children: modifications.map((mod) {
            return Card(
              margin: const EdgeInsets.only(top: 20),
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Add-on Request", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.amber.shade800)),
                  const SizedBox(height: 8),
                  Text('"${mod.description}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  Text("Additional Cost: LKR ${NumberFormat("#,##0").format(mod.additionalCost)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => _firestoreService.respondToModification(taskId: task.id, modificationId: mod.id, additionalCost: mod.additionalCost, isApproved: false), child: const Text("Reject", style: TextStyle(color: Colors.red))),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: () => _firestoreService.respondToModification(taskId: task.id, modificationId: mod.id, additionalCost: mod.additionalCost, isApproved: true), child: const Text("Approve")),
                  ])
                ]),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// --- ALL REQUIRED HELPER WIDGETS ---
class _TaskSummaryCard extends StatelessWidget {
  final Task task;
  const _TaskSummaryCard({required this.task});
  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(task.description, style: Theme.of(context).textTheme.bodyMedium),
              const Divider(height: 32),
              _buildInfoRow(context, Icons.category_outlined, "Category", task.category),
              const SizedBox(height: 12),
              _buildInfoRow(context, Icons.account_balance_wallet_rounded, "Final Price", 'LKR ${NumberFormat("#,##0").format(task.finalAmount ?? task.budget)}')
            ])));
  }
}

class _StatusInfoCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData? icon;
  final Color? color;
  const _StatusInfoCard({required this.title, required this.message, this.icon, this.color});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
        color: (color ?? theme.primaryColor).withOpacity(0.05),
        child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(children: [
              if (icon != null) ...[Icon(icon, size: 40, color: color ?? theme.primaryColor), const SizedBox(width: 20)],
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: theme.textTheme.titleLarge?.copyWith(color: color ?? theme.primaryColor)),
                    const SizedBox(height: 4),
                    Text(message, style: theme.textTheme.bodyMedium)
                  ]))
            ])));
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;
  const _ActionCard({required this.title, required this.message, required this.buttonText, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onPressed, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: Text(buttonText))
            ])));
  }
}

class _ConfirmationCodeCard extends StatelessWidget {
  final String code;
  const _ConfirmationCodeCard({required this.code});
  @override
  Widget build(BuildContext context) {
    return Card(
        color: Theme.of(context).primaryColor,
        child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(children: [
              Text("Your Helper has arrived!", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text("Show this code to your helper to confirm their arrival and start the task.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
              const SizedBox(height: 24),
              Text(code, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 12))
            ])));
  }
}

class _EnterCodeCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;
  const _EnterCodeCard({required this.controller, required this.isLoading, required this.onSubmit});
  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text("Confirm Your Arrival", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text("Enter the 4-digit code from the poster's app to begin the task.", style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              TextField(controller: controller, maxLength: 4, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold), decoration: const InputDecoration(counterText: "", hintText: "----")),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: isLoading ? null : onSubmit, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white)) : const Text("Verify Code & Start Task"))
            ])));
  }
}

class _CompleteTaskCard extends StatelessWidget {
  final bool isLoading;
  final XFile? imageFile;
  final VoidCallback onPickImage;
  final VoidCallback onComplete;
  const _CompleteTaskCard({required this.isLoading, this.imageFile, required this.onPickImage, required this.onComplete});
  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text("Complete the Task", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text("Upload a photo as proof of your work. This helps prevent disputes.", style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              Container(height: 150, width: double.infinity, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)), child: imageFile != null ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.file(File(imageFile!.path), fit: BoxFit.cover)) : const Center(child: Text('No image selected.'))),
              const SizedBox(height: 8),
              TextButton.icon(onPressed: onPickImage, icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Select Proof Photo')),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: isLoading ? null : onComplete, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white)) : const Text("Mark as Complete"))
            ])));
  }
}

class _ConfirmCompletionCard extends StatelessWidget {
  final Task task;
  final VoidCallback onConfirm;
  const _ConfirmCompletionCard({required this.task, required this.onConfirm});
  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text("Confirm Completion", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text("Your helper has marked the task as complete. Please review their work and the proof photo below.", style: Theme.of(context).textTheme.bodyMedium),
              if (task.proofImageUrl != null) ...[
                const SizedBox(height: 20),
                Text("Proof of Completion:", style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(task.proofImageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover, loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator())))
              ],
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onConfirm, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text("Confirm & Proceed to Payment"))
            ])));
  }
}

Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: Colors.grey[600], size: 20),
    const SizedBox(width: 16),
    Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))
        ]))
  ]);
}
