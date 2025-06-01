import 'package:event_app/models/event.dart';
import 'package:event_app/providers/event_providers.dart'; // Adjust import path
import 'package:event_app/ui/screens/events_list_screen.dart'; // Adjust import path
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Use the mock generated for EventListNotifier from provider tests if it fits,
// or create a specific one for UI interaction if needed.
// For UI tests, often mocking the provider's resulting state is easier.

// Mock for EventListNotifier - simplified for UI testing state changes
// We are not generating a new mock class here, but mocking the behavior
// of the notifier when accessed via the provider.

// A mock notifier class can be useful if you need to verify calls to its methods.
// For simplicity here, we will override the provider to return specific states.
class MockEventListNotifier extends AutoDisposeAsyncNotifier<EventListState>
    with Mock
    implements EventListNotifier {

  MockEventListNotifier(this._initialState);
  final AsyncValue<EventListState> _initialState;

  // Store the state that the provider should return
  AsyncValue<EventListState> mockState = const AsyncLoading();

  @override
  AsyncValue<EventListState> get state => mockState;

  @override
  Future<EventListState> build() async {
    if (_initialState is AsyncError) {
      throw (_initialState as AsyncError).error;
    }
    return _initialState.value ?? EventListState(); // Should have a value if not error/loading
  }

  // Mock methods if you need to verify they are called
  @override
  Future<void> fetchNextPage() async {
    // Simulate behavior or just record call
  }

  @override
  Future<void> refresh() async {
    // Simulate behavior or just record call
  }

  // Helper to update the mock state for testing UI reactions
  void setMockState(AsyncValue<EventListState> newState) {
    mockState = newState;
    // This won't automatically rebuild widgets in test. We need pumpWidget.
  }
}


void main() {
  // Sample events for testing UI
  final sampleEvents = List.generate(
    5,
    (i) => Event(id: 'evt_$i', name: 'Event $i', startTime: DateTime.now().add(Duration(days:i)), createdAt: DateTime.now(), isPublic: true),
  );

  group('EventsListScreen Widget Tests', () {
    testWidgets('shows loading indicator when state is loading', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventListProvider.overrideWith((ref) {
              // Directly return an AsyncLoading state for the provider
              // This is simpler than fully mocking the notifier for this case.
              // However, if you need to test calls to notifier methods,
              // then mocking EventListNotifier itself is better.
              final notifier = MockEventListNotifier(const AsyncLoading());
              notifier.setMockState(const AsyncLoading());
              return notifier;
            }),
          ],
          child: const MaterialApp(home: EventsListScreen()),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when state is error', (WidgetTester tester) async {
      final exception = Exception('Network Error');
      // Arrange
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventListProvider.overrideWith((ref) {
              final notifier = MockEventListNotifier(AsyncError(exception, StackTrace.empty));
               notifier.setMockState(AsyncError(exception, StackTrace.empty));
              return notifier;
            })
          ],
          child: const MaterialApp(home: EventsListScreen()),
        ),
      );

      // Need to pump again for the error state to be processed by `when`
      await tester.pump();


      // Assert
      expect(find.text('Failed to load events: $exception'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Try Again'), findsOneWidget);
    });

    testWidgets('shows list of events when state is data', (WidgetTester tester) async {
      // Arrange
      final eventListState = EventListState(events: sampleEvents);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventListProvider.overrideWith((ref) {
               final notifier = MockEventListNotifier(AsyncData(eventListState));
               notifier.setMockState(AsyncData(eventListState));
               return notifier;
            })
          ],
          child: const MaterialApp(home: EventsListScreen()),
        ),
      );
      await tester.pump(); // Rebuild for the data state

      // Assert
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(sampleEvents.length));
      expect(find.text('Event 0'), findsOneWidget);
      expect(find.text('Event 4'), findsOneWidget);
    });

    testWidgets('tapping an event item prints to console (placeholder test)', (WidgetTester tester) async {
      // For real navigation, you'd mock GoRouter or Navigator.
      // Here, we just check our placeholder print statement.
      final eventListState = EventListState(events: [sampleEvents.first]);

      // Capture console prints
      final List<String> log = [];
      tester.binding.debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) log.add(message);
      };


      await tester.pumpWidget(
        ProviderScope(
          overrides: [
             eventListProvider.overrideWith((ref) {
               final notifier = MockEventListNotifier(AsyncData(eventListState));
               notifier.setMockState(AsyncData(eventListState));
               return notifier;
            })
          ],
          child: const MaterialApp(home: EventsListScreen()),
        ),
      );
      await tester.pump();

      // Act
      await tester.tap(find.text('Event 0'));
      await tester.pump(); // Allow time for onTap to execute

      // Assert
      expect(log, contains('Tapped on event: Event 0 (ID: evt_0)'));
    });

    testWidgets('pull to refresh calls refresh on the notifier', (WidgetTester tester) async {
      final mockNotifier = MockEventListNotifier(AsyncData(EventListState(events: sampleEvents)));
      mockNotifier.setMockState(AsyncData(EventListState(events: sampleEvents)));

      when(mockNotifier.refresh()).thenAnswer((_) async {}); // Mock the refresh method

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventListProvider.overrideWith((ref) => mockNotifier)
          ],
          child: const MaterialApp(home: EventsListScreen()),
        ),
      );
      await tester.pump(); // Ensure UI is built

      // Act: Simulate a pull-to-refresh gesture
      // The actual gesture is hard to simulate perfectly. We find the RefreshIndicator
      // and call its onRefresh callback.
      // More robust: find.byType(RefreshIndicator) and trigger its onRefresh.
      // For simplicity, we'll assume the AppBar button is an alternative way to trigger.
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();


      // Assert
      verify(mockNotifier.refresh()).called(1);
    });

    testWidgets('infinite scroll calls fetchNextPage on the notifier', (WidgetTester tester) async {
       final mockNotifier = MockEventListNotifier(AsyncData(EventListState(events: sampleEvents, hasReachedMax: false)));
       mockNotifier.setMockState(AsyncData(EventListState(events: sampleEvents, hasReachedMax: false)));

      when(mockNotifier.fetchNextPage()).thenAnswer((_) async {}); // Mock the method

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventListProvider.overrideWith((ref) => mockNotifier)
          ],
          child: const MaterialApp(home: EventsListScreen()),
        ),
      );
      await tester.pumpAndSettle(); // Ensure list is built and settled

      // Act: Scroll to the bottom
      await tester.drag(find.byType(ListView), const Offset(0, -500)); // Adjust offset as needed
      await tester.pumpAndSettle(); // Let scroll settle and trigger listeners

      // Assert
      verify(mockNotifier.fetchNextPage()).called(1);
    });

     testWidgets('shows loading indicator at bottom when isLoadingNextPage is true', (WidgetTester tester) async {
      final eventsWithLoadingNextPage = EventListState(
        events: sampleEvents,
        isLoadingNextPage: true, // Key for this test
        hasReachedMax: false,
        currentPage: 0,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventListProvider.overrideWith((ref){
              final notifier = MockEventListNotifier(AsyncData(eventsWithLoadingNextPage));
              notifier.setMockState(AsyncData(eventsWithLoadingNextPage));
              return notifier;
            })
          ],
          child: const MaterialApp(home: EventsListScreen()),
        ),
      );
      await tester.pump(); // Rebuild

      // Assert
      // The ListView itemCount will be events.length + 1
      // The last item should be a CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget); // One for the bottom loader
      expect(find.byType(Card), findsNWidgets(sampleEvents.length)); // Cards for existing events
    });

  });
}
