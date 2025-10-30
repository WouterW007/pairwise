import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pairwise/features/transactions/data/transaction.dart';
// --- FIX: IMPORT THE ACCOUNTS PROVIDER ---
import 'package:pairwise/features/accounts/application/account_providers.dart';

// This provider will give us a real-time stream of transactions
final transactionsStreamProvider = StreamProvider<List<Transaction>>((ref) {
  final supabase = Supabase.instance.client;

  // --- THIS IS THE FIX ---
  // 1. Watch the householdIdProvider to get the household ID
  final householdIdAsyncValue = ref.watch(householdIdProvider);

  // 2. Use maybeWhen to handle the household ID's loading/data states
  return householdIdAsyncValue.maybeWhen(
    data: (householdId) {
      if (householdId == null) {
        return Stream.value([]); // No household, no transactions
      }

      // 3. Build the stream *with* the householdId filter
      final stream = supabase
          .from('transactions')
          .stream(primaryKey: ['id'])
          .eq('household_id', householdId) // <-- Filter by household
          .order('date', ascending: false);

      // 4. Map the list of maps into a list of Transaction objects
      return stream.map((listOfMaps) {
        // This is a List<Map<String, dynamic>>
        return listOfMaps.map((map) => Transaction.fromMap(map)).toList();
      });
    },
    // While householdId is loading, return an empty stream
    orElse: () => Stream.value([]),
  );
  // --- END FIX ---
});
