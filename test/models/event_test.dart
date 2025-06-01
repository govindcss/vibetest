import 'package:flutter_test/flutter_test.dart';
import 'package:event_app/models/event.dart'; // Adjust import path as per your project structure

void main() {
  group('Event Model Tests', () {
    final DateTime now = DateTime.now();
    final String nowUtc = now.toUtc().toIso8601String(); // Ensure UTC for consistent JSON
    final String eventId = 'test-event-id-123';

    final Map<String, dynamic> sampleEventJson = {
      'id': eventId,
      'created_at': nowUtc,
      'name': 'Tech Conference 2024',
      'description': 'A conference about new tech.',
      'start_time': nowUtc,
      'end_time': now.add(const Duration(hours: 8)).toUtc().toIso8601String(),
      'location_text': 'Online',
      'is_public': true,
      'created_by': 'user-abc-123',
      // 'location_coordinates' is omitted as it's complex and commented out in model
    };

    final Event sampleEvent = Event(
      id: eventId,
      createdAt: DateTime.parse(nowUtc).toLocal(), // fromJson parses to local
      name: 'Tech Conference 2024',
      description: 'A conference about new tech.',
      startTime: DateTime.parse(nowUtc).toLocal(),
      endTime: DateTime.parse(now.add(const Duration(hours: 8)).toUtc().toIso8601String()).toLocal(),
      locationText: 'Online',
      isPublic: true,
      createdBy: 'user-abc-123',
    );

    test('Event.fromJson creates correct Event object', () {
      final event = Event.fromJson(sampleEventJson);

      expect(event.id, sampleEvent.id);
      expect(event.name, sampleEvent.name);
      expect(event.description, sampleEvent.description);
      // Comparing DateTimes can be tricky due to precision/timezone.
      // Ensure they are compared consistently (e.g., after converting to UTC or using isAtSameMomentAs)
      expect(event.createdAt.isAtSameMomentAs(sampleEvent.createdAt), isTrue);
      expect(event.startTime.isAtSameMomentAs(sampleEvent.startTime), isTrue);
      expect(event.endTime!.isAtSameMomentAs(sampleEvent.endTime!), isTrue);
      expect(event.locationText, sampleEvent.locationText);
      expect(event.isPublic, sampleEvent.isPublic);
      expect(event.createdBy, sampleEvent.createdBy);
    });

    test('Event.toJson creates correct JSON map', () {
      final json = sampleEvent.toJson();

      expect(json['id'], sampleEventJson['id']);
      expect(json['name'], sampleEventJson['name']);
      expect(json['description'], sampleEventJson['description']);
      // toJson converts DateTime to ISO8601 string in UTC
      expect(json['created_at'], sampleEvent.createdAt.toUtc().toIso8601String());
      expect(json['start_time'], sampleEvent.startTime.toUtc().toIso8601String());
      expect(json['end_time'], sampleEvent.endTime!.toUtc().toIso8601String());
      expect(json['location_text'], sampleEventJson['location_text']);
      expect(json['is_public'], sampleEventJson['is_public']);
      expect(json['created_by'], sampleEventJson['created_by']);
    });

    test('Event.fromJson handles null endTime', () {
      final Map<String, dynamic> jsonWithNullEnd = Map.from(sampleEventJson);
      jsonWithNullEnd['end_time'] = null;

      final event = Event.fromJson(jsonWithNullEnd);
      expect(event.endTime, isNull);
    });

     test('Event.toJson handles null endTime', () {
      final eventWithNullEnd = Event(
        id: eventId,
        createdAt: DateTime.parse(nowUtc).toLocal(),
        name: 'Tech Conference 2024',
        startTime: DateTime.parse(nowUtc).toLocal(),
        endTime: null, // Null endTime
        isPublic: true,
      );
      final json = eventWithNullEnd.toJson();
      expect(json['end_time'], isNull);
    });
  });
}
