import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pairwise/features/transactions/data/transaction.dart';

// This provider will give us a real-time stream of transactions
final transactionsStreamProvider = StreamProvider<List<Transaction>>((ref) {
  final supabase = Supabase.instance.client;

  // 1. Get the stream of data from the 'transactions' table
  final stream = supabase.from('transactions').stream(primaryKey: ['id'])
      // 2. Order by date, newest transactions first
      .order('date', ascending: false);

  // 3. Map the list of maps into a list of Transaction objects
  return stream.map((listOfMaps) {
    // This is a List<Map<String, dynamic>>
    return listOfMaps.map((map) => Transaction.fromMap(map)).toList();
  });
});
