import 'dart:io'; // --- THIS LINE IS NOW FIXED ---
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:servana/models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  XFile? _imageFile;
  String? _networkImageUrl;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _qualificationsController;
  late TextEditingController _experienceController;
  late TextEditingController _skillsController;
  late TextEditingController _videoUrlController;

  List<String> _portfolioImageUrls = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _qualificationsController = TextEditingController();
    _experienceController = TextEditingController();
    _skillsController = TextEditingController();
    _videoUrlController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final helper = HelpifyUser.fromFirestore(userDoc);

      _nameController.text = helper.displayName ?? '';
      _bioController.text = helper.bio ?? '';
      _qualificationsController.text = helper.qualifications ?? '';
      _experienceController.text = helper.experience ?? '';
      _skillsController.text = helper.skills.join(', ');
      _videoUrlController.text = helper.videoIntroUrl ?? '';
      if(mounted) {
        setState(() {
          _networkImageUrl = helper.photoURL;
          _portfolioImageUrls = helper.portfolioImageUrls;
        });
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load profile data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) {
      setState(() {
        _imageFile = file;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    try {
      String? updatedPhotoUrl = _networkImageUrl;

      if (_imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_pictures')
            .child(user.uid)
            .child('profile.jpg');

        await ref.putFile(File(_imageFile!.path));
        updatedPhotoUrl = await ref.getDownloadURL();

        await user.updatePhotoURL(updatedPhotoUrl);
      }

      final skillsList = _skillsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      final Map<String, dynamic> dataToSave = {
        'displayName': _nameController.text.trim(),
        'photoURL': updatedPhotoUrl,
        'bio': _bioController.text.trim(),
        'qualifications': _qualificationsController.text.trim(),
        'experience': _experienceController.text.trim(),
        'skills': skillsList,
        'videoIntroUrl': _videoUrlController.text.trim(),
        'portfolioImageUrls': _portfolioImageUrls,
      };

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(dataToSave, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save profile: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadPortfolioImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;

    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser!;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child('portfolio_images').child(user.uid).child(fileName);

    try {
      await ref.putFile(File(file.path));
      final imageUrl = await ref.getDownloadURL();
      setState(() {
        _portfolioImageUrls.add(imageUrl);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image upload failed.')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _qualificationsController.dispose();
    _experienceController.dispose();
    _skillsController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            icon: _isSaving ? const SizedBox(width:20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveProfile,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(),
              const SizedBox(height: 24),

              _buildSectionHeader('Personal Information'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Your Bio'),
                maxLines: 4,
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('Professional Details'),
              TextFormField(
                controller: _skillsController,
                decoration: const InputDecoration(labelText: 'Your Skills (separated by commas)', hintText: 'Plumbing, Graphic Design, Tutoring...'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qualificationsController,
                decoration: const InputDecoration(labelText: 'Qualifications', hintText: 'e.g., NVQ Level 4'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _experienceController,
                decoration: const InputDecoration(labelText: 'Work Experience', hintText: 'e.g., 5 years at Company X'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _videoUrlController,
                decoration: const InputDecoration(labelText: 'Video Introduction URL', hintText: 'e.g., YouTube or Vimeo link'),
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('Portfolio Gallery'),
              _buildPortfolioManager(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    ImageProvider? backgroundImage;
    if (_imageFile != null) {
      backgroundImage = FileImage(File(_imageFile!.path));
    } else if (_networkImageUrl != null && _networkImageUrl!.isNotEmpty) {
      backgroundImage = NetworkImage(_networkImageUrl!);
    }

    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage: backgroundImage,
          child: backgroundImage == null ? const Icon(Icons.person, size: 60) : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickImage,
            child: const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue,
              child: Icon(Icons.edit, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 16.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
        ),
      ),
    );
  }

  Widget _buildPortfolioManager() {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _portfolioImageUrls.length + 1,
          itemBuilder: (context, index) {
            if (index == _portfolioImageUrls.length) {
              return Tooltip(
                message: "Add Photo",
                child: InkWell(
                  onTap: _isSaving ? null : _uploadPortfolioImage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: _isSaving ? const CircularProgressIndicator() : const Icon(Icons.add_a_photo, color: Colors.grey),
                    ),
                  ),
                ),
              );
            }
            final imageUrl = _portfolioImageUrls[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(imageUrl, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _portfolioImageUrls.removeAt(index);
                      });
                    },
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}