// lib/features/plaid/data/plaid_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final plaidRepositoryProvider = Provider<PlaidRepository>((ref) {
  // Get the client directly from the Supabase singleton
  final supabaseClient = Supabase.instance.client;

  // Pass the client to the repository
  return PlaidRepository(supabaseClient);
});

class PlaidRepository {
  PlaidRepository(this._client);
  final SupabaseClient _client;

  /// Creates a Plaid Link Token by calling the 'plaid-create-link-token'
  /// Edge Function.
  Future<String> createLinkToken() async {
    try {
      final response =
          await _client.functions.invoke('plaid-create-link-token');
      final data = response.data as Map<String, dynamic>;
      if (response.status != 200) {
        throw Exception('Failed to create link token: ${data['error']}');
      }
      return data['link_token'];
    } catch (e) {
      print("Error creating link token: $e");
      throw Exception('Failed to create link token: $e');
    }
  }

  // --- THIS IS THE FIX ---
  // This function is now much simpler. It only calls one Edge Function.
  Future<void> linkAccountAndSync({
    required String publicToken,
  }) async {
    try {
      // Step 1: Call 'plaid-exchange-public-token' and let it
      // handle the entire sync process.
      print('Step 1/1: Exchanging token and syncing all data...');
      final exchangeResult = await _client.functions.invoke(
        'plaid-exchange-public-token', // This function now does everything
        body: {'public_token': publicToken},
      );

      if (exchangeResult.status != 200) {
        throw Exception(
            'Failed to link and sync: ${exchangeResult.data['error']}');
      }

      print('Full initial sync complete!');
    } catch (e) {
      print('Error in linkAccountAndSync: $e');
      rethrow;
    }
  }
// --- END FIX ---
}
