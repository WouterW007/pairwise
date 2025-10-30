import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pairwise/features/household/data/household_invite.dart';

// --- FIX 1: CREATE A PROVIDER FOR THE AUTH STREAM ---
/// This provider exposes the Supabase auth stream.
/// Other providers can watch this to react to auth changes.
final authStreamProvider = StreamProvider.autoDispose((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// --- FIX 2: UPDATE PENDINGINVITESPROVIDER ---

/// Provides a one-time fetch of pending invites for the currently logged-in user.
final pendingInvitesProvider =
    FutureProvider.autoDispose<List<HouseholdInvite>>((ref) async {
  // --- THIS IS THE CORRECTED FIX ---
  // We watch the new authStreamProvider. When the user logs in or out,
  // this provider will emit a new value, which will cause
  // this FutureProvider to automatically re-run.
  ref.watch(authStreamProvider);
  // --- END FIX ---

  final supabase = Supabase.instance.client;
  final currentUserEmail = supabase.auth.currentUser?.email;

  if (currentUserEmail == null) {
    return [];
  }

  // This is your original, correct Supabase query syntax
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
