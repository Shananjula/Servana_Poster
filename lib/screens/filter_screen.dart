import 'package:flutter/material.dart';
// import 'package:servana/services/ai_service.dart'; // Assuming you have this service

class FilterScreen extends StatefulWidget {
  final ScrollController scrollController;
  // We keep initialFilters in the constructor in case you want to change back, but we won't use it.
  final Map<String, dynamic> initialFilters;

  const FilterScreen({super.key, required this.scrollController, required this.initialFilters});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late Map<String, dynamic> _currentFilters;
  final _aiSearchController = TextEditingController();
  bool _isAiProcessing = false;

  late List<String> _categories;

  // State for sliders and switches
  RangeValues _rateRange = const RangeValues(0, 50000);
  bool _isVerifiedOnly = false;

  @override
  void initState() {
    super.initState();

    // --- THIS IS THE FIX ---
    // We no longer load the previous filters. We start fresh every time.
    _currentFilters = {};

    // Initialize the default categories list. This remains the same.
    _categories = ['All', 'Home & Garden', 'Digital & Online', 'Education', 'Other'];

    // Initialize UI state to default values, ignoring any previous state.
    _rateRange = const RangeValues(0, 50000);
    _isVerifiedOnly = false;
    // --- END OF FIX ---
  }

  void _handleAiSearch() async {
    if (_aiSearchController.text.trim().isEmpty) return;
    setState(() => _isAiProcessing = true);

    // final parsedFilters = await AiService.parseFilterFromText(_aiSearchController.text);
    // This is a mock response for demonstration. The real AiService would provide this.
    final parsedFilters = {
      "category": "Plumbing", // Example AI-parsed category
      "isVerified": true,
      "rate_max": 10000,
    };

    if (mounted) {
      setState(() {
        // Add the new category from the AI to the list if it's not already there
        final newCategory = parsedFilters['category'] as String?;
        if (newCategory != null && !_categories.contains(newCategory)) {
          _categories.add(newCategory);
        }

        _currentFilters.addAll(parsedFilters);
        // Update UI elements based on AI response
        _isVerifiedOnly = _currentFilters['isVerified'] ?? _isVerifiedOnly;
        _rateRange = RangeValues(
            (_currentFilters['rate_min'] as num? ?? 0).toDouble(),
            (_currentFilters['rate_max'] as num? ?? 50000).toDouble()
        );
        _isAiProcessing = false;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Filters updated by AI!"), backgroundColor: Colors.green));
      });
    }
  }

  void _applyFilters() {
    // Consolidate UI state into the filters map before returning
    _currentFilters['rate_min'] = _rateRange.start;
    _currentFilters['rate_max'] = _rateRange.end;
    _currentFilters['isVerified'] = _isVerifiedOnly;
    Navigator.pop(context, _currentFilters);
  }

  void _resetFilters() {
    setState(() {
      _currentFilters.clear();
      _aiSearchController.clear();
      _rateRange = const RangeValues(0, 50000);
      _isVerifiedOnly = false;
      // Reset categories to the default list
      _categories = ['All', 'Home & Garden', 'Digital & Online', 'Education', 'Other'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Filters", style: theme.textTheme.headlineSmall),
                    TextButton(onPressed: _resetFilters, child: const Text("Reset"))
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _aiSearchController,
                  decoration: InputDecoration(
                    labelText: "Describe what you're looking for...",
                    hintText: "e.g., verified plumber in Colombo under 10k",
                    suffixIcon: _isAiProcessing
                        ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(icon: const Icon(Icons.auto_awesome), onPressed: _handleAiSearch, tooltip: "Filter with AI"),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader("Category", theme),
                DropdownButtonFormField<String>(
                  value: _currentFilters['category'] ?? 'All',
                  // Using .toSet().toList() is a great way to ensure the list is unique
                  items: _categories.toSet().toList().map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (value) {
                    setState(() => _currentFilters['category'] = value);
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),

                const SizedBox(height: 24),
                _buildSectionHeader("Budget / Rate (LKR)", theme),
                RangeSlider(
                  values: _rateRange,
                  min: 0,
                  max: 50000,
                  divisions: 100,
                  labels: RangeLabels(
                    _rateRange.start.round().toString(),
                    _rateRange.end.round().toString(),
                  ),
                  onChanged: (values) {
                    setState(() => _rateRange = values);
                  },
                ),

                const SizedBox(height: 24),
                _buildSectionHeader("Trust & Safety", theme),
                SwitchListTile(
                  title: const Text("Verified Helpers Only"),
                  value: _isVerifiedOnly,
                  onChanged: (value) {
                    setState(() => _isVerifiedOnly = value);
                  },
                  secondary: Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                child: const Text("Apply Filters"),
                onPressed: _applyFilters,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Text(title, style: theme.textTheme.titleMedium)
    );
  }
}
