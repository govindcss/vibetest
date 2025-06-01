import 'package:flutter/foundation.dart';

/// Represents an event in the application.
///
/// This model mirrors the structure of the `events` table in the Supabase database.
/// It includes details such as the event's name, description, timings, location,
/// and visibility status.
class Event {
  /// The unique identifier for the event (UUID).
  final String id;

  /// The timestamp when the event was created.
  final DateTime createdAt;

  /// The name of the event. This field is mandatory.
  final String name;

  /// A detailed description of the event. Optional.
  final String? description;

  /// The start date and time of the event. This field is mandatory.
  final DateTime startTime;

  /// The end date and time of the event. Optional.
  final DateTime? endTime;

  /// A text-based description of the event's location. Optional.
  final String? locationText;

  // /// Geographic coordinates of the event.
  // /// This might be a custom object or a JSON string depending on PostGIS handling.
  // final dynamic locationCoordinates; // Example: Map<String, dynamic> or custom Point class

  /// Indicates whether the event is public (true) or private (false).
  /// Defaults to true in the database.
  final bool isPublic;

  /// The unique identifier (UUID) of the user who created the event. Optional.
  final String? createdBy;

  /// Constructs an [Event] instance.
  ///
  /// All fields except [description], [endTime], [locationText], and [createdBy] are required.
  Event({
    required this.id,
    required this.createdAt,
    required this.name,
    this.description,
    required this.startTime,
    this.endTime,
    this.locationText,
    // this.locationCoordinates,
    required this.isPublic,
    this.createdBy,
  });

  /// Creates an [Event] instance from a JSON map.
  ///
  /// This factory constructor is typically used to parse data received from Supabase.
  /// It expects `created_at`, `start_time`, and `end_time` (if present) to be ISO 8601
  /// string representations, which are then parsed into [DateTime] objects (converted to local time).
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      name: json['name'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: json['end_time'] == null ? null : DateTime.parse(json['end_time'] as String).toLocal(),
      locationText: json['location_text'] as String?,
      // locationCoordinates: json['location_coordinates'], // Parse accordingly if used
      isPublic: json['is_public'] as bool? ?? true, // Default to true if null, though DB should enforce NOT NULL
      createdBy: json['created_by'] as String?,
    );
  }

  /// Converts this [Event] instance into a JSON map.
  ///
  /// This method is typically used when sending data to Supabase.
  /// [DateTime] fields are converted to ISO 8601 string representations in UTC.
  Map<String, dynamic> toJson() {
    return {
      'id': id, // Usually not sent on create, but useful for updates
      // 'created_at' is usually set by DB on create, so sending it might not be necessary or could be ignored.
      // However, if your logic relies on sending it, ensure it's in UTC.
      // 'created_at': createdAt.toUtc().toIso8601String(),
      'name': name,
      'description': description,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime?.toUtc().toIso8601String(),
      'location_text': locationText,
      // 'location_coordinates': locationCoordinates, // Convert accordingly if used
      'is_public': isPublic,
      // 'created_by' is usually set by RLS/DB on create based on auth.uid().
      // 'created_by': createdBy,
    };
  }

  /// Returns a string representation of the [Event] instance.
  /// Useful for debugging and logging.
  @override
  String toString() {
    return 'Event(id: $id, name: "$name", startTime: $startTime, isPublic: $isPublic)';
  }

  /// Implements equality comparison for [Event] instances.
  /// Two events are considered equal if their [id]s are the same.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event && other.id == id;
  }

  /// Returns the hash code for this [Event] instance, based on its [id].
  @override
  int get hashCode => id.hashCode;
}
