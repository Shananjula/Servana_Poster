import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:servana/constants/service_categories.dart'; // Import service categories to use in the prompt

/// A service class for interacting with the Google Gemini AI for various features.
class AiService {
  static final String? _apiKey = dotenv.env['GEMINI_API_KEY'];

  /// --- NEW: AI-Powered Search Query Parser ---
  /// Analyzes a natural language search query and converts it into a structured filter map.
  static Future<Map<String, dynamic>?> parseSearchQuery(String query) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint("GEMINI_API_KEY not found.");
      return null; // Return null if no API key
    }
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);

    // Create a string of all available categories to help the AI.
    final allCategories = AppServices.categories.keys.join(', ');

    // This detailed prompt instructs the AI on how to behave.
    final prompt = '''
      Analyze the user's search query: "$query".
      Your task is to extract specific filters and return them as a JSON object.
      The possible filters are:
      1. "category": A string that must be one of these exact values: [$allCategories].
      2. "searchTerm": A string containing the main subject of the search (e.g., "plumber", "leaky pipe").
      3. "isVerified": A boolean (true if the user asks for "verified", "trusted", or "pro" helpers).
      4. "minRating": A number between 1 and 5 (e.g., if the user asks for "good rating" or "4 stars and up").

      - If a filter is not mentioned in the query, do not include its key in the JSON.
      - Prioritize matching the category from the provided list.
      - The "searchTerm" should be a concise keyword.

      Examples:
      - Query: "show me verified plumbers with good ratings" -> {"category": "Home & Garden", "searchTerm": "plumber", "isVerified": true, "minRating": 4}
      - Query: "car wash" -> {"category": "Automotive Services", "searchTerm": "car wash"}
      - Query: "maths tutor for my son" -> {"category": "Lessons & Tutoring", "searchTerm": "maths tutor"}
    ''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim();
      if (text == null || text.isEmpty) return null;

      // Return the parsed JSON object which will be our filter map.
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Error parsing search query with AI: $e");
      // If AI fails, we can return a simple keyword search as a fallback.
      return {'searchTerm': query};
    }
  }

  /// Generates a task description, category, and budget from a simple title.
  static Future<Map<String, dynamic>?> getTaskSuggestionsFromTitle(String title) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint("GEMINI_API_KEY not found.");
      return null;
    }
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);
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

  /// Generates a full task from a user's text input and an image.
  static Future<Map<String, String>?> generateTaskFromImage(String userInput, Uint8List imageData) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint("GEMINI_API_KEY not found.");
      return null;
    }
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

  /// Analyzes a chat message to suggest a contextual "smart action".
  static Future<Map<String, dynamic>?> getSmartChatAction(String message) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      final lowerCaseText = message.toLowerCase();
      if (lowerCaseText.contains('meet') || lowerCaseText.contains('schedule') || lowerCaseText.contains('tomorrow')) {
        return {'action': 'schedule', 'details': 'Schedule a meeting for tomorrow?'};
      }
      if (lowerCaseText.contains('where are you') || lowerCaseText.contains('location')) {
        return {'action': 'request_location', 'details': 'Request user\'s location?'};
      }
      return null;
    }

    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);
    final prompt = 'Analyze the following chat message: "$message". Determine if it implies a specific user intent. If it suggests scheduling, return a JSON object like {"action": "schedule", "details": "Schedule a meeting?"}. If it asks for a location, return {"action": "request_location", "details": "Request location?"}. If no clear action is found, return null.';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim();

      if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
        return null;
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Error getting smart chat action with AI: $e");
      return getSmartChatAction(message);
    }
  }
}
