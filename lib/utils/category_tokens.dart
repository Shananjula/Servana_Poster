// Minimal helpers for category tokens.
// If your category docs already have aliases/parents, we’ll use them.
// Otherwise we just return the IDs themselves.

import 'package:cloud_firestore/cloud_firestore.dart';

String normalizeId(String s) {
  // slugify-ish: lowercase, trim, replace spaces and slashes
  final t = (s.trim().toLowerCase())
      .replaceAll(RegExp(r'[^a-z0-9\/ _-]'), '')
      .replaceAll(RegExp(r'\s+'), '_');
  return t.isEmpty ? 'uncategorized' : t;
}

Future<Set<String>> computeCategoryTokens(List<String> categoryIds) async {
  final db = FirebaseFirestore.instance;
  final tokens = <String>{};

  for (final id in categoryIds) {
    tokens.add(id); // always include the ID
    try {
      final doc = await db.collection('categories').doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final aliases = (data['aliases'] is List)
            ? List<String>.from(data['aliases'])
            : const <String>[];
        final parents = (data['parents'] is List)
            ? List<String>.from(data['parents'])
            : const <String>[];

        for (final a in aliases) tokens.add(normalizeId(a));
        for (final p in parents) tokens.add(normalizeId(p));
      }
    } catch (_) {
      // ignore document read errors, still return basic tokens
    }
  }
  return tokens;
}
