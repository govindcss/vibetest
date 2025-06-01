class EventUser {
  final String eventId; // UUID
  final String userId; // UUID
  final DateTime joinedAt;
  final String role;

  EventUser({
    required this.eventId,
    required this.userId,
    required this.joinedAt,
    required this.role,
  });

  factory EventUser.fromJson(Map<String, dynamic> json) {
    return EventUser(
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'user_id': userId,
      'joined_at': joinedAt.toIso8601String(),
      'role': role,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EventUser &&
      other.eventId == eventId &&
      other.userId == userId;
  }

  @override
  int get hashCode => eventId.hashCode ^ userId.hashCode;

  @override
  String toString() {
    return 'EventUser(eventId: $eventId, userId: $userId, role: $role, joinedAt: $joinedAt)';
  }
}
