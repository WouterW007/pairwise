import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pairwise/features/household/data/household_invite.dart';

/// Provides a one-time fetch of pending invites for the currently logged-in user.
///
/// Our RLS policy "Allow users to see their own invites"
/// automatically secures this query.
final pendingInvitesProvider =
    FutureProvider<List<HouseholdInvite>>((ref) async {
  final supabase = Supabase.instance.client;
  final currentUserEmail = supabase.auth.currentUser?.email;

  if (currentUserEmail == null) {
    // Return an empty list if user is logged out
    return [];
  }

  // --- THIS IS THE FIX ---
  // We use a standard .select() query, which *does* have .eq()
  final response = await supabase
      .from('household_invites')
      .select()
      .eq('invitee_email', currentUserEmail)
      .eq('status', 'pending');

  // The 'response' from a .select() is a List<dynamic>
  final listOfMaps = response as List<dynamic>;

  // Map the list of maps into a list of HouseholdInvite objects
  return listOfMaps
      .map((map) => HouseholdInvite.fromMap(map as Map<String, dynamic>))
      .toList();
});
