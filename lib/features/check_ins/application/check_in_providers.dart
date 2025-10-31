// lib/features/check_ins/application/check_in_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/features/accounts/application/account_providers.dart';
import 'package:pairwise/features/check_ins/data/check_in_message.dart';
import 'package:pairwise/features/check_ins/data/check_in_session.dart';
import 'package:pairwise/main.dart';

/// Provides a stream of all past check-in sessions for the household.
final checkInSessionsStreamProvider =
    StreamProvider<List<CheckInSession>>((ref) {
  final householdIdAsync = ref.watch(householdIdProvider);

  return householdIdAsync.maybeWhen(
    data: (householdId) {
      if (householdId == null) return Stream.value([]);

      final stream = supabase
          .from('check_in_sessions')
          .stream(primaryKey: ['id'])
          .eq('household_id', householdId)
          .order('created_at', ascending: false);

      return stream.map(
          (maps) => maps.map((map) => CheckInSession.fromMap(map)).toList());
    },
    orElse: () => Stream.value([]),
  );
});

/// Provides a stream of messages for a *specific* check-in session.
final checkInMessagesStreamProvider =
    StreamProvider.family<List<CheckInMessage>, String>((ref, sessionId) {
  // We can just stream directly. RLS policies will ensure the user
  // can only see messages for sessions they belong to.
  final stream = supabase
      .from('check_in_messages')
      .stream(primaryKey: ['id'])
      .eq('session_id', sessionId)
      .order('created_at', ascending: true); // Show oldest first

  return stream
      .map((maps) => maps.map((map) => CheckInMessage.fromMap(map)).toList());
});
