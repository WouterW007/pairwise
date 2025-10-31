// lib/features/check_ins/data/check_in_session.dart
class CheckInSession {
  CheckInSession({
    required this.id,
    required this.householdId,
    required this.createdAt,
    this.title,
  });

  final String id;
  final String householdId;
  final DateTime createdAt;
  final String? title;

  factory CheckInSession.fromMap(Map<String, dynamic> map) {
    return CheckInSession(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      title: map['title'] as String?,
    );
  }
}
