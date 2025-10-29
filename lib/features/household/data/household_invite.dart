// This class models the data from the 'household_invites' table
class HouseholdInvite {
  HouseholdInvite({
    required this.id,
    required this.createdAt,
    required this.householdId,
    required this.inviterId,
    required this.inviteeEmail,
    required this.status,
  });

  final String id; // UUID
  final DateTime createdAt;
  final String householdId; // UUID
  final String inviterId; // UUID
  final String inviteeEmail;
  final String status; // 'pending', 'accepted', 'declined'

  factory HouseholdInvite.fromMap(Map<String, dynamic> map) {
    try {
      return HouseholdInvite(
        id: map['id'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        householdId: map['household_id'] as String,
        inviterId: map['inviter_id'] as String,
        inviteeEmail: map['invitee_email'] as String,
        status: map['status'] as String,
      );
    } catch (e) {
      print('Error parsing HouseholdInvite from map: $e');
      print('Map causing error: $map');
      rethrow;
    }
  }

  @override
  String toString() {
    return 'HouseholdInvite(id: $id, inviteeEmail: $inviteeEmail, status: $status)';
  }
}
