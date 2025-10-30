import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/main.dart'; // To get supabase client

// Define a simple Account model (you can expand this later)
class Account {
  final String id;
  final String name;
  final String mask;
  final double? currentBalance;
  final String visibility; // 'private' or 'shared'

  Account({
    required this.id,
    required this.name,
    required this.mask,
    this.currentBalance,
    required this.visibility,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      mask: json['mask'] as String? ?? 'N/A', // Handle potential null mask
      // Handle potential String balance before parsing
      currentBalance: (json['current_balance'] is String)
          ? double.tryParse(json['current_balance'])
          : (json['current_balance'] as num?)?.toDouble(),
      visibility: json['visibility'] as String,
    );
  }
}

// Provider to get the current user's household_id
// We need this to filter the accounts stream
final householdIdProvider = FutureProvider<String?>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  // --- THIS IS THE FIX ---
  // The table is 'users', not 'profiles'
  final profile = await supabase
      .from('users') // <-- WAS 'profiles'
      .select('household_id')
      .eq('id', user.id)
      .single();
  // --- END FIX ---

  return profile['household_id'] as String?;
});

// StreamProvider to listen to the accounts table
final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  // Watch the householdIdProvider. When it resolves, this stream will rebuild.
  final householdIdAsyncValue = ref.watch(householdIdProvider);

  // Use maybeWhen to handle loading/error states of the householdIdProvider
  return householdIdAsyncValue.maybeWhen(
    data: (householdId) {
      if (householdId == null) {
        // If no household ID, return an empty stream
        return Stream.value([]);
      }
      // Listen to the accounts table, filtered by household_id
      final stream = supabase
          .from('accounts')
          .stream(primaryKey: ['id']) // Specify the primary key column(s)
          .eq('household_id', householdId) // Filter by household
          .order('name', ascending: true); // Order alphabetically by name

      // Map the stream data (List<Map<String, dynamic>>) to our Account model
      return stream.map((listOfMaps) {
        return listOfMaps.map((map) => Account.fromJson(map)).toList();
      });
    },
    // If householdIdProvider is loading or has error, return an empty stream
    orElse: () => Stream.value([]),
  );
});
