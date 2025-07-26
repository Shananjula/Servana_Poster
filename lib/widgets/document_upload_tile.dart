import 'package:flutter/material.dart';
import 'package:servana/services/storage_service.dart';
import 'dart:io';

// Enum to manage the state of the upload for each tile
enum UploadStatus {
  pending, // Not yet uploaded
  uploading, // In progress
  complete, // Successfully uploaded
  error, // An error occurred
}

class DocumentUploadTile extends StatefulWidget {
  final String documentName; // e.g., "National ID - Front"
  final String documentType; // The field name in Firestore, e.g., "nicFrontUrl"
  final IconData icon;
  final String? initialUrl; // The URL if the document is already uploaded

  const DocumentUploadTile({
    super.key,
    required this.documentName,
    required this.documentType,
    required this.icon,
    this.initialUrl,
  });

  @override
  State<DocumentUploadTile> createState() => _DocumentUploadTileState();
}

class _DocumentUploadTileState extends State<DocumentUploadTile> {
  late UploadStatus _status;
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    // Set the initial state based on whether a URL was provided
    _status = (widget.initialUrl != null && widget.initialUrl!.isNotEmpty)
        ? UploadStatus.complete
        : UploadStatus.pending;
  }

  Future<void> _handleUpload() async {
    setState(() => _status = UploadStatus.uploading);

    // 1. Pick the image file
    File? fileToUpload = await _storageService.pickImage();
    if (fileToUpload == null) {
      setState(() => _status = UploadStatus.pending); // User cancelled picker
      return;
    }

    // 2. Upload the file and update Firestore
    String? downloadUrl = await _storageService.uploadFileAndUpdateUser(
      file: fileToUpload,
      documentType: widget.documentType,
      context: context,
    );

    // 3. Update the UI based on the result
    if (mounted) {
      setState(() {
        _status = (downloadUrl != null) ? UploadStatus.complete : UploadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        leading: Icon(widget.icon, size: 40, color: Theme.of(context).colorScheme.primary),
        title: Text(widget.documentName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_getStatusText()),
        trailing: _buildTrailingWidget(),
      ),
    );
  }

  Widget _buildTrailingWidget() {
    switch (_status) {
      case UploadStatus.pending:
        return ElevatedButton(
          onPressed: _handleUpload,
          child: const Text("Upload"),
        );
      case UploadStatus.uploading:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 3),
        );
      case UploadStatus.complete:
        return const Icon(Icons.check_circle, color: Colors.green, size: 30);
      case UploadStatus.error:
      // Allow re-trying on error
        return IconButton(
          icon: const Icon(Icons.refresh, color: Colors.red),
          onPressed: _handleUpload,
        );
    }
  }

  String _getStatusText() {
    switch (_status) {
      case UploadStatus.pending:
        return "Awaiting upload";
      case UploadStatus.uploading:
        return "Uploading...";
      case UploadStatus.complete:
        return "Upload successful";
      case UploadStatus.error:
        return "Upload failed. Please try again.";
    }
  }
}
