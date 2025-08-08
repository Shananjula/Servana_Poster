import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servana/models/user_model.dart';
import 'package:servana/services/ai_service.dart';
import 'package:servana/services/firestore_service.dart'; // Import the service
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_picker_screen.dart';

enum TaskType { physical, online }
enum PaymentMethod { cash, card, servCoins }

class PostTaskScreen extends StatefulWidget {
  const PostTaskScreen({Key? key}) : super(key: key);

  @override
  State<PostTaskScreen> createState() => _PostTaskScreenState();
}

class _PostTaskScreenState extends State<PostTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();

  // Add a reference to your service
  final FirestoreService _firestoreService = FirestoreService();

  // State variables remain the same
  bool _isGeneratingSuggestions = false;
  String? _suggestedBudget;
  Timer? _debounce;
  TaskType _selectedTaskType = TaskType.physical;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.card;
  String? _selectedCategory;
  String? _selectedSubCategory;
  XFile? _imageFile;
  String? _imageUrl;
  GeoPoint? _selectedLocation;
  String _locationAddress = 'No location selected';
  bool _isSubmitting = false;
  bool _isFetchingLocation = false;
  bool _isUploadingImage = false;
  final Map<String, List<String>> _categories = {
    'Home & Garden': ['Plumbing', 'Handyman', 'Gardening', 'Cleaning', 'Moving', 'Appliance Repair'],
    'Digital & Online': ['Graphic & Design', 'Writing & Translation', 'Digital Marketing', 'Tech & Programming', 'Data Entry'],
    'Education': ['Math Tutoring', 'Science Tutoring', 'Language Lessons', 'Music Lessons'],
    'Other': ['Delivery', 'Events & Photography', 'Vehicle Repair', 'Other'],
  };
  List<String> _subCategories = [];

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 1000), () {
        if (_titleController.text.trim().length > 10) {
          _getAiSuggestions();
        }
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getAiSuggestions() async {
    setState(() => _isGeneratingSuggestions = true);
    final suggestions = await AiService.getTaskSuggestionsFromTitle(_titleController.text.trim());
    if (suggestions != null && mounted) {
      setState(() {
        if(_descriptionController.text.trim().isEmpty) {
          _descriptionController.text = suggestions['description'] ?? '';
        }
        final suggestedCategory = suggestions['category'];
        if (suggestedCategory != null && _categories.containsKey(suggestedCategory)) {
          _selectedCategory = suggestedCategory;
          _subCategories = _categories[suggestedCategory] ?? [];
          _selectedSubCategory = null;
        }
        final budget = suggestions['budget'];
        if(budget != null) {
          _suggestedBudget = budget.toString();
        }
      });
    }
    setState(() => _isGeneratingSuggestions = false);
  }

  Future<void> _generateTaskFromImage() async {
    if (_imageFile == null) return;
    setState(() => _isGeneratingSuggestions = true);
    final imageData = await _imageFile!.readAsBytes();
    final suggestions = await AiService.generateTaskFromImage(_titleController.text.trim(), imageData);
    if(suggestions != null && mounted) {
      setState(() {
        _titleController.text = suggestions['title'] ?? _titleController.text;
        _descriptionController.text = suggestions['description'] ?? _descriptionController.text;
        final suggestedCategory = suggestions['category'];
        if (suggestedCategory != null && _categories.containsKey(suggestedCategory)) {
          _selectedCategory = suggestedCategory;
          _subCategories = _categories[suggestedCategory] ?? [];
          _selectedSubCategory = null;
        }
        final budget = suggestions['budget'];
        if (budget != null) {
          _suggestedBudget = budget;
          _budgetController.text = budget;
        }
      });
    }
    setState(() => _isGeneratingSuggestions = false);
  }

  // --- THIS FUNCTION IS NOW SIMPLIFIED ---
  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
      return;
    }
    if (_selectedTaskType == TaskType.physical && _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a location for a physical task.')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      // First, check the user's balance to avoid unnecessary uploads
      const double postingFee = 10.0;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = HelpifyUser.fromFirestore(userDoc);

      if (userData.servCoinBalance < 100) {
        throw Exception('You need at least 100 Serv Coins to post a task.');
      }
      if (userData.servCoinBalance < postingFee) {
        throw Exception('Insufficient Serv Coins. You need $postingFee coins to post.');
      }

      // Upload image if it exists
      if (_imageFile != null) {
        setState(() => _isUploadingImage = true);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child('task_images').child(user.uid).child(fileName);
        await ref.putFile(File(_imageFile!.path));
        _imageUrl = await ref.getDownloadURL();
        setState(() => _isUploadingImage = false);
      }

      final budget = double.tryParse(_budgetController.text) ?? 0.0;

      // Prepare the data map
      final taskData = {
        'taskType': _selectedTaskType.name,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'subCategory': _selectedSubCategory,
        'location': _selectedTaskType == TaskType.physical ? _selectedLocation : null,
        'locationAddress': _selectedTaskType == TaskType.physical ? _locationAddress : null,
        'budget': budget,
        'imageUrl': _imageUrl,
        'paymentMethod': _selectedPaymentMethod.name,
        'posterId': user.uid,
        'posterName': user.displayName ?? 'Helpify User',
        'posterAvatarUrl': user.photoURL ?? '',
        'status': 'open',
        'timestamp': FieldValue.serverTimestamp(),
        'participantIds': [user.uid],
      };

      // Call the centralized service function
      await _firestoreService.postNewTask(
        taskData: taskData,
        postingFee: postingFee,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task posted successfully! $postingFee coins deducted.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Location functions and build method remain the same...
  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Location permissions are permanently denied.');

      final position = await Geolocator.getCurrentPosition();
      _updateLocation(LatLng(position.latitude, position.longitude));

    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _selectOnMap() async {
    final pickedLocation = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (ctx) => const MapPickerScreen()),
    );
    if (pickedLocation == null) return;
    _updateLocation(pickedLocation);
  }

  Future<void> _updateLocation(LatLng location) async {
    setState(() {
      _selectedLocation = GeoPoint(location.latitude, location.longitude);
      _locationAddress = "Fetching address...";
    });
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _locationAddress = "${place.name ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}".replaceAll(RegExp(r'^, |, $'), '');
        });
      }
    } catch (e) {
      setState(() => _locationAddress = "Lat: ${location.latitude.toStringAsFixed(2)}, Lon: ${location.longitude.toStringAsFixed(2)}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post a New Task'),
        actions: [
          if(_isSubmitting)
            const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)))
          else
            IconButton(icon: const Icon(Icons.check), onPressed: _submitTask, tooltip: 'Post Task')
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('1. Choose Task Type'),
              _buildTaskTypeSelector(),
              const SizedBox(height: 24),
              _buildSectionHeader('2. Describe your Task'),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Task Title',
                  suffixIcon: _isGeneratingSuggestions ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width:20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                ),
                validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 5,
                validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
              ),
              if (_selectedTaskType == TaskType.physical) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('3. Set Location'),
                _buildLocationInput(),
              ],
              const SizedBox(height: 24),
              _buildSectionHeader(_selectedTaskType == TaskType.physical ? '4. Payment & Details' : '3. Payment & Details'),
              _buildPaymentMethodSelector(),
              const SizedBox(height: 16),
              _buildCategorySelectors(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Your Budget (LKR)'),
                validator: (value) => value!.isEmpty ? 'Please enter a budget' : null,
              ),
              if (_suggestedBudget != null)
                _buildBudgetSuggestion(),

              const SizedBox(height: 24),
              _buildSectionHeader(_selectedTaskType == TaskType.physical ? '5. Add a Photo (Optional)' : '4. Add a Photo (Optional)'),
              _buildImagePicker(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text("How will you pay?", style: Theme.of(context).textTheme.titleMedium),
        ),
        SegmentedButton<PaymentMethod>(
          style: SegmentedButton.styleFrom(
            foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
            selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
            selectedBackgroundColor: Theme.of(context).colorScheme.primary,
          ),
          segments: const <ButtonSegment<PaymentMethod>>[
            ButtonSegment<PaymentMethod>(value: PaymentMethod.card, label: Text('Card'), icon: Icon(Icons.credit_card)),
            ButtonSegment<PaymentMethod>(value: PaymentMethod.cash, label: Text('Cash'), icon: Icon(Icons.money_outlined)),
            ButtonSegment<PaymentMethod>(value: PaymentMethod.servCoins, label: Text('Serv Coins'), icon: Icon(Icons.monetization_on_outlined)),
          ],
          selected: <PaymentMethod>{_selectedPaymentMethod},
          onSelectionChanged: (Set<PaymentMethod> newSelection) {
            setState(() {
              _selectedPaymentMethod = newSelection.first;
            });
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTaskTypeSelector() {
    return SegmentedButton<TaskType>(
      style: SegmentedButton.styleFrom(
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
        selectedBackgroundColor: Theme.of(context).colorScheme.primary,
      ),
      segments: const <ButtonSegment<TaskType>>[
        ButtonSegment<TaskType>(
          value: TaskType.physical,
          label: Text('Physical'),
          icon: Icon(Icons.location_on_outlined),
        ),
        ButtonSegment<TaskType>(
          value: TaskType.online,
          label: Text('Online'),
          icon: Icon(Icons.language),
        ),
      ],
      selected: <TaskType>{_selectedTaskType},
      onSelectionChanged: (Set<TaskType> newSelection) {
        setState(() {
          _selectedTaskType = newSelection.first;
          _selectedCategory = null;
          _selectedSubCategory = null;
          _subCategories = [];
        });
      },
    );
  }

  Widget _buildCategorySelectors() {
    final relevantCategories = _selectedTaskType == TaskType.online
        ? _categories.keys.where((k) => k == 'Digital & Online' || k == 'Education' || k == 'Other').toList()
        : _categories.keys.where((k) => k != 'Digital & Online').toList();

    if (_selectedCategory != null && !relevantCategories.contains(_selectedCategory)) {
      _selectedCategory = null;
      _selectedSubCategory = null;
      _subCategories = [];
    }

    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: const InputDecoration(labelText: 'Category'),
          items: relevantCategories
              .map((label) => DropdownMenuItem(child: Text(label), value: label))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value;
              _selectedSubCategory = null;
              _subCategories = _categories[value] ?? [];
            });
          },
          validator: (value) => value == null ? 'Please select a category' : null,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: _subCategories.isNotEmpty
              ? Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedSubCategory,
              decoration: const InputDecoration(labelText: 'Sub-Category'),
              items: _subCategories
                  .map((label) => DropdownMenuItem(child: Text(label), value: label))
                  .toList(),
              onChanged: (value) => setState(() => _selectedSubCategory = value),
              validator: (value) => value == null ? 'Please select a sub-category' : null,
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: Column(
        children: [
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isUploadingImage
                ? const Center(child: CircularProgressIndicator())
                : _imageFile != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(_imageFile!.path), fit: BoxFit.cover),
            )
                : const Center(child: Text('No image selected.')),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                  if (file != null) {
                    setState(() => _imageFile = file);
                  }
                },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Select an Image'),
              ),
              if (_imageFile != null)
                TextButton.icon(
                  onPressed: _generateTaskFromImage,
                  icon: Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor),
                  label: Text('Analyze with AI', style: TextStyle(color: Theme.of(context).primaryColor)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_locationAddress, style: const TextStyle(fontSize: 16))),
                  ],
                ),
                if (_isFetchingLocation) const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: LinearProgressIndicator(),
                ),
              ],
            )
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.my_location),
              label: const Text('Use Current'),
              onPressed: _isFetchingLocation ? null : _getCurrentLocation,
            ),
            TextButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: const Text('Set on Map'),
              onPressed: _selectOnMap,
            ),
          ],
        )
      ],
    );
  }

  Widget _buildBudgetSuggestion() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text("✨ AI Suggestion: LKR $_suggestedBudget", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800))),
          TextButton(
            onPressed: () {
              setState(() {
                _budgetController.text = _suggestedBudget!;
              });
            },
            child: const Text("Apply"),
          )
        ],
      ),
    );
  }
}