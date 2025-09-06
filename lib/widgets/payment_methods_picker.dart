// lib/widgets/payment_methods_picker.dart
import 'package:flutter/material.dart';
import '../models/payment_method.dart';

class PaymentMethodsPicker extends StatefulWidget {
  final Set<PaymentMethod>? initial;
  final String? initialOtherNote;
  final void Function(Set<PaymentMethod> methods, String? otherNote) onChanged;

  const PaymentMethodsPicker({
    super.key,
    this.initial,
    this.initialOtherNote,
    required this.onChanged,
  });

  @override
  State<PaymentMethodsPicker> createState() => _PaymentMethodsPickerState();
}

class _PaymentMethodsPickerState extends State<PaymentMethodsPicker> {
  late Set<PaymentMethod> _selected;
  final _otherCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = {...(widget.initial ?? {PaymentMethod.servcoins})};
    _otherCtrl.text = widget.initialOtherNote ?? '';
  }

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  void _toggle(PaymentMethod m) {
    setState(() {
      if (_selected.contains(m)) {
        _selected.remove(m);
      } else {
        if (_selected.length >= 4) return; // cap at 4
        _selected.add(m);
      }
    });
    widget.onChanged(
      _selected,
      _selected.contains(PaymentMethod.other) ? _otherCtrl.text.trim() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final methods = PaymentMethod.values;
    final needsOther = _selected.contains(PaymentMethod.other);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How will you pay the helper?',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: methods
              .map(
                (m) => FilterChip(
              avatar: Icon(m.icon, size: 18),
              label: Text(m.label),
              selected: _selected.contains(m),
              onSelected: (_) => _toggle(m),
            ),
          )
              .toList(),
        ),
        if (needsOther) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _otherCtrl,
            maxLength: 80,
            onChanged: (_) => widget.onChanged(_selected, _otherCtrl.text.trim()),
            decoration: const InputDecoration(
              labelText: 'Other method (short note)',
              hintText: 'e.g., Cash on delivery after inspection',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}
