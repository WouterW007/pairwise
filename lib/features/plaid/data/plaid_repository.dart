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

  /// Chains Plaid token exchange, account fetching, and transaction sync.
  Future<void> linkAccountAndSync({
    required String publicToken,
  }) async {
    try {
      // Step 1: Call 'plaid-exchange-public-token'
      final exchangeResult = await _client.functions.invoke(
        'plaid-exchange-public-token',
        body: {'public_token': publicToken},
      );

      if (exchangeResult.status != 200) {
        throw Exception(
            'Failed to exchange public token: ${exchangeResult.data['error']}');
      }

      final String plaidItemId = exchangeResult.data['plaid_item_id'];
      final String dbItemUuid = exchangeResult.data['db_item_uuid'];

      if (plaidItemId.isEmpty || dbItemUuid.isEmpty) {
        throw Exception('Failed to get item IDs from token exchange.');
      }
      print('Step 1/3: Public token exchanged successfully.');

      // Step 2: Call 'plaid-fetch-accounts'
      final fetchResult = await _client.functions.invoke(
        'plaid-fetch-accounts',
        body: {
          'plaid_item_id': plaidItemId,
          'db_item_uuid': dbItemUuid,
        },
      );

      if (fetchResult.status != 200) {
        throw Exception(
            'Failed to fetch accounts: ${fetchResult.data['error']}');
      }
      print('Step 2/3: Accounts fetched successfully.');

      // Step 3: Call 'plaid-sync-transactions' (The NEW step)
      final syncResult = await _client.functions.invoke(
        'plaid-sync-transactions',
        body: {
          'plaid_item_id': plaidItemId,
          'db_item_uuid': dbItemUuid, // <-- THIS IS THE FIX
        },
      );

      if (syncResult.status != 200) {
        throw Exception(
            'Failed to sync transactions: ${syncResult.data['error']}');
      }
      print('Step 3/3: Initial transactions synced successfully.');
    } catch (e) {
      print('Error in linkAccountAndSync: $e');
      rethrow;
    }
  }
}
