import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:event_app/models/event.dart'; // Adjust import path
import 'package:event_app/models/chat_message.dart'; // Adjust import path
import 'package:event_app/repositories/event_repository.dart'; // Adjust import path

// Import the generated mocks
import 'event_repository_test.mocks.dart';

// Annotations for generating mocks. Run build_runner to generate.
@GenerateMocks([
  SupabaseClient,
  GoTrueClient, // For mocking auth.currentUser
  SupabaseQueryBuilder,
  PostgrestFilterBuilder, // SupabaseQueryBuilder returns this
  RealtimeChannel,        // Though not directly used in methods being tested, good to have if expanding
  PostgrestResponse,      // To mock the response from execute()
  User,                   // For mocking currentUser
])
void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late MockSupabaseQueryBuilder mockSupabaseQueryBuilder;
  late MockPostgrestFilterBuilder mockPostgrestFilterBuilder; // Renamed for clarity
  late MockPostgrestResponse mockPostgrestResponse;
  late MockUser mockUser;
  late EventRepository eventRepository;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    mockSupabaseQueryBuilder = MockSupabaseQueryBuilder();
    mockPostgrestFilterBuilder = MockPostgrestFilterBuilder();
    mockPostgrestResponse = MockPostgrestResponse();
    mockUser = MockUser();

    // Setup default behavior for SupabaseClient.auth and SupabaseClient.from
    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    when(mockSupabaseClient.from(any)).thenReturn(mockSupabaseQueryBuilder);

    // Setup default behavior for SupabaseQueryBuilder methods to return itself or a PostgrestFilterBuilder
    when(mockSupabaseQueryBuilder.select(any)).thenReturn(mockSupabaseQueryBuilder); // if select takes params
    when(mockSupabaseQueryBuilder.select()).thenReturn(mockSupabaseQueryBuilder);    // if select takes no params
    when(mockSupabaseQueryBuilder.insert(any, valueMatcher: anyNamed('valueMatcher'))).thenReturn(mockSupabaseQueryBuilder);
    when(mockSupabaseQueryBuilder.update(any, valueMatcher: anyNamed('valueMatcher'))).thenReturn(mockSupabaseQueryBuilder);
    when(mockSupabaseQueryBuilder.delete(valueMatcher: anyNamed('valueMatcher'))).thenReturn(mockSupabaseQueryBuilder);

    // Setup SupabaseQueryBuilder to return PostgrestFilterBuilder for chaining
    // These PostgrestFilterBuilder methods then need to return themselves for further chaining
    when(mockSupabaseQueryBuilder.eq(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockSupabaseQueryBuilder.neq(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockSupabaseQueryBuilder.gt(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockSupabaseQueryBuilder.gte(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockSupabaseQueryBuilder.lt(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockSupabaseQueryBuilder.lte(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockSupabaseQueryBuilder.like(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockSupabaseQueryBuilder.ilike(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockSupabaseQueryBuilder.is_(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockSupabaseQueryBuilder.in_(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockSupabaseQueryBuilder.contains(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockSupabaseQueryBuilder.containedBy(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockSupabaseQueryBuilder.range(any, any)).thenReturn(mockPostgrestFilterBuilder); // range returns PFB
    when(mockSupabaseQueryBuilder.order(any, ascending: anyNamed('ascending'))).thenReturn(mockPostgrestFilterBuilder); // order returns PFB
    when(mockSupabaseQueryBuilder.limit(any)).thenReturn(mockPostgrestFilterBuilder); // limit returns PFB
    when(mockSupabaseQueryBuilder.single()).thenReturn(mockPostgrestFilterBuilder); // single returns PFB

    // Setup PostgrestFilterBuilder methods to return itself for chaining, then execute
    when(mockPostgrestFilterBuilder.eq(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.neq(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.gt(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.gte(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.lt(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.lte(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.like(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.ilike(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.is_(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.in_(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.contains(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.containedBy(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.range(any, any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.order(any, ascending: anyNamed('ascending'))).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.limit(any)).thenReturn(mockPostgrestFilterBuilder);
    when(mockPostgrestFilterBuilder.single()).thenReturn(mockPostgrestFilterBuilder);

    // Finally, mock the execute() call on PostgrestFilterBuilder
    when(mockPostgrestFilterBuilder.execute()).thenAnswer((_) async => mockPostgrestResponse);
    // And also on SupabaseQueryBuilder if execute can be called directly on it
    when(mockSupabaseQueryBuilder.execute()).thenAnswer((_) async => mockPostgrestResponse);


    eventRepository = EventRepository(client: mockSupabaseClient);
  });

  group('EventRepository Tests', () {
    group('fetchEvents', () {
      final List<Map<String, dynamic>> sampleEventData = [
        {
          'id': '1', 'name': 'Event 1', 'description': 'Desc 1',
          'start_time': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(), 'is_public': true
        },
        {
          'id': '2', 'name': 'Event 2', 'description': 'Desc 2',
          'start_time': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(), 'is_public': false
        },
      ];

      test('successfully fetches events', () async {
        // Arrange
        when(mockPostgrestResponse.error).thenReturn(null);
        when(mockPostgrestResponse.data).thenReturn(sampleEventData);
        // Ensure the chain of mocks is correctly set up for this specific call path
        when(mockSupabaseClient.from('events')).thenReturn(mockSupabaseQueryBuilder);
        when(mockSupabaseQueryBuilder.select()).thenReturn(mockSupabaseQueryBuilder);
        when(mockSupabaseQueryBuilder.order('start_time', ascending: true)).thenReturn(mockPostgrestFilterBuilder); // order returns PFB
        when(mockPostgrestFilterBuilder.range(0, 19)).thenReturn(mockPostgrestFilterBuilder); // range returns PFB
        when(mockPostgrestFilterBuilder.execute()).thenAnswer((_) async => mockPostgrestResponse);


        // Act
        final events = await eventRepository.fetchEvents();

        // Assert
        expect(events, isA<List<Event>>());
        expect(events.length, 2);
        expect(events[0].name, 'Event 1');
        verify(mockSupabaseClient.from('events')).called(1);
        verify(mockSupabaseQueryBuilder.select()).called(1);
        verify(mockSupabaseQueryBuilder.order('start_time', ascending: true)).called(1);
        verify(mockPostgrestFilterBuilder.range(0, 19)).called(1); // Default page=0, pageSize=20
        verify(mockPostgrestFilterBuilder.execute()).called(1);
      });

      test('handles Supabase error when fetching events', () async {
        // Arrange
        final supabaseError = PostgrestError(message: 'Connection error');
        when(mockPostgrestResponse.error).thenReturn(supabaseError);
        when(mockPostgrestResponse.data).thenReturn(null); // Or an empty list, depending on what Supabase does
         when(mockSupabaseClient.from('events')).thenReturn(mockSupabaseQueryBuilder);
        when(mockSupabaseQueryBuilder.select()).thenReturn(mockSupabaseQueryBuilder);
        when(mockSupabaseQueryBuilder.order('start_time', ascending: true)).thenReturn(mockPostgrestFilterBuilder);
        when(mockPostgrestFilterBuilder.range(0, 19)).thenReturn(mockPostgrestFilterBuilder);
        when(mockPostgrestFilterBuilder.execute()).thenAnswer((_) async => mockPostgrestResponse);


        // Act & Assert
        expect(() async => await eventRepository.fetchEvents(),
               throwsA(predicate((e) => e is Exception && e.toString().contains('Failed to fetch events: Connection error'))));
        verify(mockPostgrestFilterBuilder.execute()).called(1);
      });

       test('returns empty list when data is null', () async {
        when(mockPostgrestResponse.error).thenReturn(null);
        when(mockPostgrestResponse.data).thenReturn(null); // Null data
        when(mockSupabaseClient.from('events')).thenReturn(mockSupabaseQueryBuilder);
        when(mockSupabaseQueryBuilder.select()).thenReturn(mockSupabaseQueryBuilder);
        when(mockSupabaseQueryBuilder.order('start_time', ascending: true)).thenReturn(mockPostgrestFilterBuilder);
        when(mockPostgrestFilterBuilder.range(0, 19)).thenReturn(mockPostgrestFilterBuilder);
        when(mockPostgrestFilterBuilder.execute()).thenAnswer((_) async => mockPostgrestResponse);

        final events = await eventRepository.fetchEvents();
        expect(events, isEmpty);
      });
    });

    group('sendChatMessage', () {
      const eventId = 'test-event';
      const message = 'Hello world';
      const userId = 'test-user-id';

      setUp(() {
        when(mockGoTrueClient.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn(userId);
      });

      test('successfully sends a chat message', () async {
        // Arrange
        when(mockPostgrestResponse.error).thenReturn(null);
        // For insert, data might be null or the inserted record, depending on Supabase.
        // Often, we don't strictly check the response.data for simple inserts unless returning the record.
        when(mockPostgrestResponse.data).thenReturn(null);

        when(mockSupabaseClient.from('event_chats')).thenReturn(mockSupabaseQueryBuilder);
        when(mockSupabaseQueryBuilder.insert(any, valueMatcher: anyNamed('valueMatcher'))).thenReturn(mockSupabaseQueryBuilder); // insert returns SQB
        when(mockSupabaseQueryBuilder.execute()).thenAnswer((_) async => mockPostgrestResponse); // execute on SQB


        // Act
        await eventRepository.sendChatMessage(eventId: eventId, message: message);

        // Assert
        final expectedInsertData = {
          'event_id': eventId,
          'user_id': userId,
          'message': message,
        };
        verify(mockSupabaseClient.from('event_chats')).called(1);
        // Use argThat to verify the map contents
        verify(mockSupabaseQueryBuilder.insert(argThat(equals(expectedInsertData)), valueMatcher: anyNamed('valueMatcher'))).called(1);
        verify(mockSupabaseQueryBuilder.execute()).called(1);
      });

      test('throws exception if user is not authenticated', () async {
        // Arrange
        when(mockGoTrueClient.currentUser).thenReturn(null);

        // Act & Assert
        expect(() async => await eventRepository.sendChatMessage(eventId: eventId, message: message),
               throwsA(predicate((e) => e is Exception && e.toString().contains('User not authenticated'))));
        verifyNever(mockSupabaseClient.from('event_chats'));
      });

      test('throws exception if message is empty', () async {
        // Arrange
        // User is authenticated
        when(mockGoTrueClient.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn(userId);

        // Act & Assert
        expect(() async => await eventRepository.sendChatMessage(eventId: eventId, message: '  '), // Empty message
               throwsA(predicate((e) => e is Exception && e.toString().contains('Message cannot be empty'))));
        verifyNever(mockSupabaseClient.from('event_chats'));
      });

      test('handles Supabase error when sending message', () async {
        // Arrange
        final supabaseError = PostgrestError(message: 'Network issue');
        when(mockPostgrestResponse.error).thenReturn(supabaseError);
        when(mockPostgrestResponse.data).thenReturn(null);

        when(mockSupabaseClient.from('event_chats')).thenReturn(mockSupabaseQueryBuilder);
        when(mockSupabaseQueryBuilder.insert(any, valueMatcher: anyNamed('valueMatcher'))).thenReturn(mockSupabaseQueryBuilder);
        when(mockSupabaseQueryBuilder.execute()).thenAnswer((_) async => mockPostgrestResponse);

        // Act & Assert
        expect(() async => await eventRepository.sendChatMessage(eventId: eventId, message: message),
               throwsA(predicate((e) => e is Exception && e.toString().contains('Failed to send message: Network issue'))));
      });
    });
  });
}
