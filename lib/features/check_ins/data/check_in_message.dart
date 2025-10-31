// lib/features/check_ins/data/check_in_message.dart
class CheckInMessage {
  CheckInMessage({
    required this.id,
    required this.sessionId,
    this.userId,
    required this.createdAt,
    required this.order,
    required this.content,
  });

  final String id;
  final String sessionId;
  final String? userId; // Null for app prompts
  final DateTime createdAt;
  final int order;
  final String content;

  bool get isFromApp => userId == null;

  factory CheckInMessage.fromMap(Map<String, dynamic> map) {
    return CheckInMessage(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      userId: map['user_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      order: (map['order'] as num).toInt(),
      content: map['content'] as String,
    );
  }
}
