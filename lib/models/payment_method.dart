// lib/models/payment_method.dart
import 'package:flutter/material.dart';

enum PaymentMethod { bankTransfer, servcoins, card, cash, other }

extension PaymentMethodX on PaymentMethod {
  String get id => switch (this) {
    PaymentMethod.bankTransfer => 'bank_transfer',
    PaymentMethod.servcoins => 'servcoins',
    PaymentMethod.card => 'card',
    PaymentMethod.cash => 'cash',
    PaymentMethod.other => 'other',
  };

  String get label => switch (this) {
    PaymentMethod.bankTransfer => 'Bank transfer',
    PaymentMethod.servcoins => 'ServCoins',
    PaymentMethod.card => 'Card',
    PaymentMethod.cash => 'Cash',
    PaymentMethod.other => 'Other (specify)',
  };

  IconData get icon => switch (this) {
    PaymentMethod.bankTransfer => Icons.account_balance,
    PaymentMethod.servcoins => Icons.token,
    PaymentMethod.card => Icons.credit_card,
    PaymentMethod.cash => Icons.payments,
    PaymentMethod.other => Icons.more_horiz,
  };

  static PaymentMethod fromId(String id) => switch (id) {
    'bank_transfer' => PaymentMethod.bankTransfer,
    'servcoins' => PaymentMethod.servcoins,
    'card' => PaymentMethod.card,
    'cash' => PaymentMethod.cash,
    _ => PaymentMethod.other,
  };
}
