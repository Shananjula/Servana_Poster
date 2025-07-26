// lib/services/ai_service.dart - UPDATED

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  static final String? _apiKey = dotenv.env['GEMINI_API_KEY'];

  // --- NEW: Consolidated function for creating a task from text ---
  static Future<Map<String, dynamic>?> getTaskSuggestionsFromTitle(String title) async {
    if (_apiKey == null || _apiKey!.isEmpty) return null;
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);

    // This prompt asks for description, category, and budget all at once.
    final prompt = 'Analyze the task title: "$title". Based on this, generate a JSON object with: 1) a "description" template prompting the user for details (using markdown bolding for headers), 2) a suggested "category" from ["Home & Garden", "Digital & Online", "Education", "Other"], and 3) a suggested "budget" as an integer in LKR. Example Response: {"description": "**Type of Work:** [e.g., Repair, Installation]", "category": "Home & Garden", "budget": 3500}';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim();
      if (text == null || text.isEmpty) return null;
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Error getting task suggestions with AI: $e");
      return null;
    }
  }

  // --- Multi-Modal Task Creation (Your existing function is great) ---
  static Future<Map<String, String>?> generateTaskFromImage(String userInput, Uint8List imageData) async {
    if (_apiKey == null || _apiKey!.isEmpty) return null;
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);
    final imagePart = DataPart('image/jpeg', imageData);
    final prompt = TextPart('Analyze the image and the user text: "$userInput". Generate a JSON object with a "title", a detailed "description", a suggested "category" from ["Home & Garden", "Digital & Online", "Education", "Other"], and a suggested "budget" in LKR. For example: {"title": "Repair Leaky Kitchen Sink", "description": "**Location of Leak:** Under the sink...\\n**Severity:** Dripping consistently...", "category": "Home & Garden", "budget": "3000"}');
    try {
      final response = await model.generateContent([Content.multi([prompt, imagePart])]);
      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim();
      if (text == null || text.isEmpty) return null;
      return Map<String, String>.from(jsonDecode(text));
    } catch (e) {
      debugPrint("Error generating task from image with AI: $e");
      return null;
    }
  }

  // These other functions are ready for when we build out other screens!
  static Future<Map<String, dynamic>?> generateProfileFromBio(String bio) async {
    // ... your existing code ...
    return null;
  }

  static Future<Map<String, dynamic>?> getSmartChatAction(String message) async {
    // ... your existing code ...
    return null;
  }
}