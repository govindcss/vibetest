import 'package:flutter/foundation.dart';

class Event {
  final String id; // UUID
  final DateTime createdAt;
  final String name;
  final String? description;
  final DateTime startTime;
  final DateTime? endTime;
  final String? locationText;
  // final dynamic locationCoordinates; // PostGIS type, handle as needed, maybe String or custom obj
  final bool isPublic;
  final String? createdBy; // UUID of the user

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

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      name: json['name'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] == null ? null : DateTime.parse(json['end_time'] as String),
      locationText: json['location_text'] as String?,
      // locationCoordinates: json['location_coordinates'], // Parse accordingly
      isPublic: json['is_public'] as bool,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'name': name,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'location_text': locationText,
      // 'location_coordinates': locationCoordinates,
      'is_public': isPublic,
      'created_by': createdBy,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Event &&
      other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Event(id: $id, name: $name, startTime: $startTime)';
  }
}
