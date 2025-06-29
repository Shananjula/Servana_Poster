import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:typed_data';

/// A centralized service to handle all interactions with the Google Gemini API.
class AiService {
  static final String? _apiKey = dotenv.env['GEMINI_API_KEY'];

  // --- AI-Powered Task Creation ---
  static Future<String?> generateTaskDescription(String title) async {
    if (_apiKey == null || _apiKey!.isEmpty) return null;
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);

    final prompt =
        'Based on the task title "$title", generate a helpful, structured description template for a user posting a task on a marketplace app. The template should prompt the user for key details. Format it with markdown-style bolding for headings. For example, for "Fix kitchen sink", you might generate: "**Location of Leak:** [e.g., under the sink]\n**Severity:** [e.g., slow drip]".';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (e) {
      print("Error generating task description with AI: $e");
      return null;
    }
  }

  // --- AI-Powered Helper Profile Analysis ---
  static Future<List<String>> suggestSkillsFromBio(String bio) async {
    if (_apiKey == null || _apiKey!.isEmpty) return [];
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);

    final prompt =
        'Analyze the following user bio from a skills marketplace app. Extract and suggest a list of relevant, concise skill tags. Return ONLY a comma-separated list of skills. For example: "Plumbing,Graphic Design,Maths Tutoring".\n\nBio: "$bio"';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) return [];
      return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } catch(e) {
      print("Error suggesting skills with AI: $e");
      return [];
    }
  }

  // --- AI-Powered Community Feed ---
  static Future<String?> generateCommunityPostCaption(String taskTitle, String helperName, String posterName) async {
    if (_apiKey == null || _apiKey!.isEmpty) return null;
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);

    final prompt = 'Generate a short, cheerful caption for a social media post about a completed task on our app "Helpify". The task title is "$taskTitle". The Helper is named "$helperName" and the Poster is "$posterName". Tag the users with an "@" symbol. Include a positive emoji and the hashtag #HelpifySuccess.';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text;
    } catch(e) {
      print("Error generating post caption with AI: $e");
      return null;
    }
  }

  // --- AI-Powered Vision for Moderation ---
  static Future<bool> isImageSafe(Uint8List imageData) async {
    if (_apiKey == null || _apiKey!.isEmpty) return true; // Default to safe if no key
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey!);

    final imagePart = DataPart('image/jpeg', imageData);
    final prompt = TextPart("Analyze this image. Is it safe for a general audience and appropriate for a community social feed? Does it contain any adult content, violence, hate speech, or depictions of self-harm? Answer with only 'SAFE' or 'UNSAFE'.");

    try {
      final response = await model.generateContent([Content.multi([prompt, imagePart])]);
      return response.text?.toUpperCase().contains('SAFE') ?? false;
    } catch(e) {
      print("Error analyzing image with AI: $e");
      return false; // Assume unsafe on error
    }
  }
}
