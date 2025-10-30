// lib/features/goals/application/goal_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/features/accounts/application/account_providers.dart'; // We need this for the householdIdProvider
import 'package:pairwise/features/goals/data/goal.dart';
import 'package:pairwise/main.dart'; // For supabase client

/// Provides a real-time stream of all goals for the current household.
final goalsStreamProvider = StreamProvider<List<Goal>>((ref) {
  // 1. Watch the householdIdProvider. When it resolves, this stream will rebuild.
  final householdIdAsyncValue = ref.watch(householdIdProvider);

  // 2. Use maybeWhen to handle loading/error states
  return householdIdAsyncValue.maybeWhen(
    data: (householdId) {
      if (householdId == null) {
        // If no household ID, return an empty stream
        return Stream.value([]);
      }

      // 3. Listen to the 'goals' table, filtered by household_id.
      // Our RLS policy "Enable ALL access for household members on goals"
      // ensures this is secure and correct.
      final stream = supabase
          .from('goals')
          .stream(primaryKey: ['id'])
          .eq('household_id', householdId)
          .order('created_at', ascending: false); // Show newest first

      // 4. Map the stream data to our Goal model
      return stream.map((listOfMaps) {
        return listOfMaps.map((map) => Goal.fromMap(map)).toList();
      });
    },
    // If householdIdProvider is loading or has error, return an empty stream
    orElse: () => Stream.value([]),
  );
});
