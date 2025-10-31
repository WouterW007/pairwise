// lib/features/check_ins/data/check_in_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/features/accounts/application/account_providers.dart';
import 'package:pairwise/main.dart'; // For supabase client

final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  return CheckInRepository(ref);
});

class CheckInRepository {
  CheckInRepository(this._ref);
  final Ref _ref;

  /// Creates a new check-in session and adds the first prompt.
  Future<String> createCheckInSession() async {
    final householdId = await _ref.read(householdIdProvider.future);
    if (householdId == null) {
      throw Exception('User is not in a household.');
    }

    // 1. Create the session header
    final session = {
      'household_id': householdId,
      'title': 'Money Date - ${DateTime.now().toIso8601String()}',
    };

    final response = await supabase
        .from('check_in_sessions')
        .insert(session)
        .select('id')
        .single();

    final String newSessionId = response['id'];

    // 2. Add the first automated prompt [cite: 410]
    final firstPrompt = {
      'session_id': newSessionId,
      'user_id': null, // App prompt
      'order': 0,
      'content':
          "Let's start by looking at last month's spending. What's one purchase you felt really good about?",
    };

    await supabase.from('check_in_messages').insert(firstPrompt);

    // 3. Return the new session ID so we can navigate to it
    return newSessionId;
  }

  /// Adds a user's reply to a check-in session [cite: 412]
  Future<void> addMessage({
    required String sessionId,
    required String content,
    int order = 1,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated.');
    }

    final message = {
      'session_id': sessionId,
      'user_id': userId, // User reply
      'order': order,
      'content': content,
    };

    await supabase.from('check_in_messages').insert(message);
  }
}
