class ChatMessage {
  final int id; // BIGSERIAL from DB
  final String eventId; // UUID
  final String userId; // UUID
  final String message;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.message,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String, // Assuming user_id is never null in DB for a sent message
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    // 'id' is usually not needed for sending, as it's auto-generated
    return {
      'event_id': eventId,
      'user_id': userId,
      'message': message,
      'created_at': createdAt.toIso8601String(), // Usually set by DB (DEFAULT NOW())
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatMessage &&
      other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ChatMessage(id: $id, eventId: $eventId, userId: $userId, message: "$message", createdAt: $createdAt)';
  }
}
