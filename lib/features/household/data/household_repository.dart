import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider to access the repository
final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return HouseholdRepository(Supabase.instance.client);
});

class HouseholdRepository {
  HouseholdRepository(this._client);
  final SupabaseClient _client;

  /// Calls the 'invite-partner' Edge Function
  Future<void> invitePartner(String email) async {
    try {
      final response = await _client.functions.invoke(
        'invite-partner',
        body: {'invitee_email': email},
      );

      if (response.status != 200) {
        throw Exception('Failed to send invite: ${response.data['error']}');
      }

      print('Invite sent successfully!');
    } catch (e) {
      print('Error in invitePartner: $e');
      rethrow;
    }
  }

  /// Calls the 'accept-invite' Edge Function (RPC)
  Future<void> acceptInvite(String inviteId) async {
    try {
      final response = await _client.functions.invoke(
        'accept-invite',
        body: {'invite_id': inviteId},
      );

      if (response.status != 200) {
        throw Exception('Failed to accept invite: ${response.data['error']}');
      }

      print('Invite accepted successfully!');
    } catch (e) {
      print('Error in acceptInvite: $e');
      rethrow;
    }
  }
}
