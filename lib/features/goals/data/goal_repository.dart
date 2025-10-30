import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/features/accounts/application/account_providers.dart';
import 'package:pairwise/main.dart'; // For supabase client

// Provider to access the repository
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(ref);
});

class GoalRepository {
  GoalRepository(this._ref);
  final Ref _ref;

  /// Creates a new goal in the database for the user's household
  Future<void> createGoal({
    required String name,
    required double targetAmount,
  }) async {
    try {
      // 1. Get the user's household ID from the provider we already built
      final householdId = await _ref.read(householdIdProvider.future);
      if (householdId == null) {
        throw Exception('User is not associated with a household.');
      }

      // 2. Prepare the data to insert
      final newGoal = {
        'household_id': householdId,
        'name': name,
        'target_amount': targetAmount,
        'current_amount': 0.0, // Start at 0
      };

      // 3. Insert into the 'goals' table
      // Our RLS policy "Enable ALL access for household members on goals"
      // will check this insert and allow it.
      await supabase.from('goals').insert(newGoal);
    } catch (e) {
      print('Error creating goal: $e');
      rethrow;
    }
  }

  /// Adds a new contribution to a specific goal by calling our RPC
  Future<void> addContribution({
    required String goalId,
    required double amount,
  }) async {
    try {
      // 1. Prepare the parameters for our 'add_goal_contribution' RPC
      final params = {
        'goal_id_to_add_to': goalId,
        'contribution_amount': amount,
      };

      // 2. Call the database function
      // This will transactionally add the contribution AND update the goal's total
      await supabase.rpc('add_goal_contribution', params: params);
    } catch (e) {
      print('Error adding contribution: $e');
      rethrow;
    }
  }
}
