/// Represents the association between a user and an event.
///
/// This model mirrors the structure of the `event_users` junction table in the Supabase database.
/// It includes the event ID, user ID, when the user joined, and their role within the event.
class EventUser {
  /// The unique identifier (UUID) of the event.
  final String eventId;

  /// The unique identifier (UUID) of the user.
  final String userId;

  /// The timestamp when the user joined the event.
  final DateTime joinedAt;

  /// The role of the user within the event (e.g., 'attendee', 'host', 'moderator').
  /// Defaults to 'attendee' in the database.
  final String role;

  /// Constructs an [EventUser] instance.
  EventUser({
    required this.eventId,
    required this.userId,
    required this.joinedAt,
    required this.role,
  });

  /// Creates an [EventUser] instance from a JSON map.
  ///
  /// This factory constructor is typically used to parse data received from Supabase.
  /// It expects `joined_at` to be an ISO 8601 string representation, which is then
  /// parsed into a [DateTime] object (converted to local time).
  factory EventUser.fromJson(Map<String, dynamic> json) {
    return EventUser(
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String).toLocal(),
      role: json['role'] as String? ?? 'attendee', // Default if null, though DB enforces NOT NULL
    );
  }

  /// Converts this [EventUser] instance into a JSON map.
  ///
  /// This method is typically used when sending data to Supabase, for example,
  /// when a user joins an event.
  /// [DateTime] fields are converted to ISO 8601 string representations in UTC.
  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'user_id': userId,
      // 'joined_at' is usually set by DB default on insert.
      // 'joined_at': joinedAt.toUtc().toIso8601String(),
      'role': role, // Role might be set on insert or updated later.
    };
  }

  /// Returns a string representation of the [EventUser] instance.
  /// Useful for debugging and logging.
  @override
  String toString() {
    return 'EventUser(eventId: $eventId, userId: $userId, role: "$role", joinedAt: $joinedAt)';
  }

  /// Implements equality comparison for [EventUser] instances.
  /// Two [EventUser] objects are considered equal if both their [eventId] and [userId] are the same.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventUser &&
      other.eventId == eventId &&
      other.userId == userId;
  }

  /// Returns the hash code for this [EventUser] instance.
  /// The hash code is based on a combination of [eventId] and [userId].
  @override
  int get hashCode => eventId.hashCode ^ userId.hashCode;
}
