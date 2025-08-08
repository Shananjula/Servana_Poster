import 'package:flutter/material.dart';
import 'package:servana/constants/service_categories.dart'; // <-- IMPORT aour central services list

class FilterScreen extends StatefulWidget {
  final ScrollController scrollController;
  final Map<String, dynamic> initialFilters;

  const FilterScreen({super.key, required this.scrollController, required this.initialFilters});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late Map<String, dynamic> _currentFilters;
  final _aiSearchController = TextEditingController();
  bool _isAiProcessing = false;

  // --- NEW: State for new UI components ---
  double _distanceValue = 50.0; // Default to 50km
  RangeValues _rateRange = const RangeValues(0, 50000);
  bool _isVerifiedOnly = false;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _currentFilters = Map<String, dynamic>.from(widget.initialFilters);

    // Initialize UI state from the incoming filters
    _selectedCategory = _currentFilters['category'];
    _rateRange = RangeValues(
      (_currentFilters['rate_min'] as num? ?? 0).toDouble(),
      (_currentFilters['rate_max'] as num? ?? 50000).toDouble(),
    );
    _distanceValue = (_currentFilters['distance'] as num? ?? 50.0).toDouble();
    _isVerifiedOnly = _currentFilters['isVerified'] ?? false;
  }

  void _applyFilters() {
    // Consolidate UI state into the filters map before returning
    _currentFilters['category'] = _selectedCategory;
    _currentFilters['rate_min'] = _rateRange.start;
    _currentFilters['rate_max'] = _rateRange.end;
    _currentFilters['distance'] = _distanceValue;
    _currentFilters['isVerified'] = _isVerifiedOnly;
    Navigator.pop(context, _currentFilters);
  }

  void _resetFilters() {
    setState(() {
      _currentFilters.clear();
      _aiSearchController.clear();
      _selectedCategory = null;
      _rateRange = const RangeValues(0, 50000);
      _distanceValue = 50.0;
      _isVerifiedOnly = false;
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
          // --- NEW: Grab Handle ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Filters", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(onPressed: _resetFilters, child: const Text("Reset All"))
                  ],
                ),
                const SizedBox(height: 24),

                // --- CATEGORY CHIPS ---
                _buildSectionHeader("Category", theme),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: AppServices.categories.keys.map((category) {
                    final isSelected = _selectedCategory == category;
                    return ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected ? category : null;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // --- DISTANCE SLIDER ---
                _buildSectionHeader("Distance (km)", theme),
                Column(
                  children: [
                    Slider(
                      value: _distanceValue,
                      min: 1,
                      max: 50, // Max distance of 50km
                      divisions: 49,
                      label: _distanceValue < 50 ? '${_distanceValue.round()} km' : '50+ km (Any)',
                      onChanged: (value) {
                        setState(() => _distanceValue = value);
                      },
                    ),
                    Text(
                      _distanceValue < 50 ? 'Within ${_distanceValue.round()} km' : 'Any Distance',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- BUDGET SLIDER ---
                _buildSectionHeader("Budget / Rate (LKR)", theme),
                RangeSlider(
                  values: _rateRange,
                  min: 0,
                  max: 50000,
                  divisions: 100,
                  labels: RangeLabels(
                    'LKR ${_rateRange.start.round()}',
                    'LKR ${_rateRange.end.round()}',
                  ),
                  onChanged: (values) {
                    setState(() => _rateRange = values);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('LKR ${_rateRange.start.round()}', style: theme.textTheme.bodySmall),
                    Text('LKR ${_rateRange.end.round()}', style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 24),

                // --- VERIFIED SWITCH ---
                _buildSectionHeader("Trust & Safety", theme),
                SwitchListTile(
                  title: const Text("Verified Helpers Only"),
                  value: _isVerifiedOnly,
                  onChanged: (value) {
                    setState(() => _isVerifiedOnly = value);
                  },
                  secondary: Icon(Icons.verified_user_outlined, color: theme.colorScheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: Colors.grey.withOpacity(0.1),
                ),
              ],
            ),
          ),
          // --- APPLY BUTTON ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Apply Filters"),
              onPressed: _applyFilters,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))
    );
  }
}
