// lib/features/goals/data/goal.dart
class Goal {
  Goal({
    required this.id,
    required this.householdId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.dueDate,
    required this.createdAt,
  });

  final String id; // UUID
  final String householdId; // UUID
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? dueDate;
  final DateTime createdAt;

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      name: map['name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      currentAmount: (map['current_amount'] as num).toDouble(),
      dueDate: map['due_date'] == null
          ? null
          : DateTime.parse(map['due_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
