import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  static final String? _apiKey = dotenv.env['GEMINI_API_KEY'];

  // --- NEW: AI-Powered Smart Profile Builder ---
  static Future<Map<String, dynamic>?> generateProfileFromBio(String bio) async {
    if (_apiKey == null || _apiKey!.isEmpty) return null;
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);
    final prompt = 'Analyze the following user bio. Extract their full name, a list of specific skills (e.g., ["Plumbing", "Graphic Design"]), their primary qualification, and suggest an hourly rate in LKR. Respond ONLY with a valid JSON object. For example: {"displayName": "John Doe", "skills": ["Plumbing", "Tiling"], "qualifications": "NVQ Level 4", "suggestedRate": 2500}\n\nBio: "$bio"';
    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim();
      if (text == null || text.isEmpty) return null;
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Error generating profile with AI: $e");
      return null;
    }
  }

  // --- NEW: Multi-Modal Task Creation ---
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

  // --- NEW: AI-Powered Smart Chat Actions ---
  static Future<Map<String, dynamic>?> getSmartChatAction(String message) async {
    if (_apiKey == null || _apiKey!.isEmpty) return null;
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);
    final prompt = 'Analyze this chat message: "$message". If it mentions scheduling (e.g., "tomorrow at 2pm"), respond with JSON: {"action": "schedule", "details": "summary of time"}. If it asks for location (e.g., "where are you?"), respond with {"action": "request_location"}. Otherwise, respond with {"action": "none"}.';
    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final data = jsonDecode(response.text ?? '{}') as Map<String, dynamic>;
      if (data['action'] != 'none') {
        return data;
      }
      return null;
    } catch (e) {
      debugPrint("Error with smart chat action AI: $e");
      return null;
    }
  }

  // Your existing functions can also be updated for more robustness
  static Future<String?> generateTaskDescription(String title) async {
    if (_apiKey == null || _apiKey!.isEmpty) return null;
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);
    final prompt = 'Based on the task title "$title", generate a helpful, structured description template for a user posting a task on a marketplace app. The template should prompt the user for key details. Format it with markdown-style bolding for headings. For example, for "Fix kitchen sink", you might generate: "**Location of Leak:** [e.g., under the sink]\\n**Severity:** [e.g., slow drip]".';
    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (e) {
      debugPrint("Error generating task description with AI: $e");
      return null;
    }
  }
}
