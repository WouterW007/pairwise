import 'package:flutter/foundation.dart';

// This is the Dart model for our 'transactions' table in Supabase
class Transaction {
  Transaction({
    required this.id,
    this.createdAt, // Made nullable
    required this.accountId,
    required this.householdId, // Added
    required this.plaidTransactionId,
    required this.name,
    required this.amount,
    required this.date,
    this.isoCurrencyCode, // Made nullable
    this.category,
    this.merchantName,
    required this.pending,
  });

  final String id; // Our UUID
  final DateTime? createdAt; // Can be null if missing
  final String accountId; // Foreign key
  final String householdId; // Foreign key
  final String plaidTransactionId;
  final String name;
  final double amount; // Converted from numeric
  final DateTime date;
  final String? isoCurrencyCode; // Can be null
  final String? category;
  final String? merchantName;
  final bool pending;

  // Factory constructor to create a Transaction from a Supabase map
  factory Transaction.fromMap(Map<String, dynamic> map) {
    try {
      return Transaction(
        id: map['id'] as String,

        // --- FIXES ARE HERE ---
        // Handle potentially null timestamps
        createdAt: map['created_at'] == null
            ? null
            : DateTime.parse(map['created_at'] as String),

        accountId: map['account_id'] as String,

        // Add missing household_id
        householdId: map['household_id'] as String,

        plaidTransactionId: map['plaid_transaction_id'] as String,
        name: map['name'] as String,

        // Handle numeric/double conversion
        amount: (map['amount'] as num).toDouble(),

        date: DateTime.parse(map['date'] as String),

        // Handle potentially null strings
        isoCurrencyCode: map['iso_currency_code'] as String?,
        category: map['category'] as String?,
        merchantName: map['merchant_name'] as String?,

        pending: map['pending'] as bool,
      );
    } catch (e) {
      print('Error parsing Transaction from map: $e');
      print('Map causing error: $map');
      rethrow;
    }
  }

  @override
  String toString() {
    return 'Transaction(id: $id, name: $name, amount: $amount, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Transaction &&
        other.id == id &&
        other.plaidTransactionId == plaidTransactionId;
  }

  @override
  int get hashCode => id.hashCode ^ plaidTransactionId.hashCode;
}
