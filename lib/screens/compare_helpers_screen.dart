// lib/screens/compare_helpers_screen.dart
//
// CompareHelpersScreen — side-by-side up to 3 helpers
// Highlights better values in green (price lower, rating higher, reviews higher, on-time higher, reply mins lower)
//
import 'dart:math' as math;
import 'package:flutter/material.dart';

class CompareHelpersScreen extends StatelessWidget {
  const CompareHelpersScreen({super.key, required this.helpers});
  final List<Map<String, dynamic>> helpers;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cols = helpers.take(3).toList();
    final names = cols.map((h) => (h['displayName'] ?? 'Helper').toString()).toList();

    double _num(String key, {double def = 0}) {
      final v = cols.map((h) => (h[key] as num?)?.toDouble() ?? def).toList();
      return v.isEmpty ? def : v.reduce((a, b) => a + b) / v.length;
    }

    // Helpers for highlight: for each row compute best index/indices
    List<int> bestIndices(List<num?> values, {bool higherIsBetter = true}) {
      final valid = <int, num>{};
      for (var i = 0; i < values.length; i++) {
        final v = values[i];
        if (v != null) valid[i] = v;
      }
      if (valid.isEmpty) return const [];
      final bestVal = higherIsBetter ? valid.values.reduce(math.max) : valid.values.reduce(math.min);
      return valid.entries.where((e) => e.value == bestVal).map((e) => e.key).toList();
    }

    Widget row(String title, List<num?> vals, {bool higherIsBetter = true, String Function(num)? fmt}) {
      final best = bestIndices(vals, higherIsBetter: higherIsBetter);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            SizedBox(width: 140, child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            for (var i = 0; i < cols.length; i++) ...[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: best.contains(i) ? Colors.green.withOpacity(0.12) : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    vals[i] == null ? '—' : (fmt != null ? fmt(vals[i]!) : vals[i]!.toStringAsFixed(1)),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: best.contains(i) ? FontWeight.w800 : FontWeight.w400),
                  ),
                ),
              ),
              if (i < cols.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      );
    }

    List<num?> _vals(String key) => cols.map((h) => (h[key] is num) ? (h[key] as num).toDouble() : null).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Compare')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 140),
                for (final n in names) ...[
                  Expanded(child: Text(n, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          row('Price (from LKR)', _vals('priceFrom'), higherIsBetter: false, fmt: (v) => v.toStringAsFixed(0)),
          const SizedBox(height: 8),
          row('Rating', _vals('rating'), higherIsBetter: true, fmt: (v) => v.toStringAsFixed(1)),
          const SizedBox(height: 8),
          row('Reviews', _vals('reviewsCount'), higherIsBetter: true, fmt: (v) => v.toStringAsFixed(0)),
          const SizedBox(height: 8),
          row('On-time %', _vals('onTimeRate')..asMap().forEach((i,v){ if (v!=null) _vals('onTimeRate')[i] = v*100; }), higherIsBetter: true, fmt: (v) => '${v.toStringAsFixed(0)}%'),
          const SizedBox(height: 8),
          row('Reply mins', _vals('replyMins'), higherIsBetter: false, fmt: (v) => v.toStringAsFixed(0)),
        ],
      ),
    );
  }
}
