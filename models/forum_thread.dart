class ForumThread {
  final int id;
  final String eventId; // UUID
  final String? userId; // UUID, can be null if user deleted/not set
  final String title;
  final String? content;
  final DateTime createdAt;
  final DateTime updatedAt;

  ForumThread({
    required this.id,
    required this.eventId,
    this.userId,
    required this.title,
    this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ForumThread.fromJson(Map<String, dynamic> json) {
    return ForumThread(
      id: json['id'] as int,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String?,
      title: json['title'] as String,
      content: json['content'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    // 'id' is auto-generated, 'created_at', 'updated_at' are usually set by DB
    return {
      'event_id': eventId,
      'user_id': userId, // Should be set to current user during creation
      'title': title,
      'content': content,
    };
  }

   @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ForumThread && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ForumThread(id: $id, eventId: $eventId, title: "$title", updatedAt: $updatedAt)';
  }
}
