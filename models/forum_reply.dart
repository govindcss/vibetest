class ForumReply {
  final int id;
  final int threadId;
  final String? userId; // UUID, can be null
  final String message;
  final DateTime createdAt;
  final int? parentReplyId; // For nested replies

  ForumReply({
    required this.id,
    required this.threadId,
    this.userId,
    required this.message,
    required this.createdAt,
    this.parentReplyId,
  });

  factory ForumReply.fromJson(Map<String, dynamic> json) {
    return ForumReply(
      id: json['id'] as int,
      threadId: json['thread_id'] as int,
      userId: json['user_id'] as String?,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      parentReplyId: json['parent_reply_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    // 'id' and 'created_at' are usually set by DB
    return {
      'thread_id': threadId,
      'user_id': userId, // Should be set to current user during creation
      'message': message,
      'parent_reply_id': parentReplyId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ForumReply && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ForumReply(id: $id, threadId: $threadId, message: "$message", parentReplyId: $parentReplyId)';
  }
}
