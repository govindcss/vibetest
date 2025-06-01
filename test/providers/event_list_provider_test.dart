import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:event_app/models/event.dart'; // Adjust import path
import 'package:event_app/repositories/event_repository.dart'; // Adjust import path
import 'package:event_app/providers/event_providers.dart'; // Adjust import path

// Import the generated mocks for EventRepository
import 'event_list_provider_test.mocks.dart';

// Annotate to generate a mock for EventRepository
@GenerateMocks([EventRepository])
void main() {
  late MockEventRepository mockEventRepository;

  // Helper to create a ProviderContainer with overrides
  ProviderContainer createContainer({
    required MockEventRepository repository,
  }) {
    final container = ProviderContainer(
      overrides: [
        eventRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // Sample events for testing
  final sampleEventsPage1 = List.generate(
    20, // pageSize
    (i) => Event(id: 'p1_$i', name: 'Event P1 $i', startTime: DateTime.now(), createdAt: DateTime.now(), isPublic: true),
  );
  final sampleEventsPage2 = List.generate(
    10,
    (i) => Event(id: 'p2_$i', name: 'Event P2 $i', startTime: DateTime.now(), createdAt: DateTime.now(), isPublic: true),
  );

  setUp(() {
    mockEventRepository = MockEventRepository();
  });

  group('EventListNotifier Tests', () {
    test('initial state is loading and then fetches first page', () async {
      // Arrange
      when(mockEventRepository.fetchEvents(page: 0, pageSize: 20))
          .thenAnswer((_) async => sampleEventsPage1);

      final container = createContainer(repository: mockEventRepository);
      final listener = ProviderListener<AsyncValue<EventListState>>();
      container.listen(eventListProvider, listener, fireImmediately: true);

      // Assert initial loading state
      expect(
        container.read(eventListProvider),
        const AsyncValue<EventListState>.loading(),
      );

      // Wait for the build method to complete
      await container.read(eventListProvider.future);

      // Assert state after fetching first page
      final state = container.read(eventListProvider).value;
      expect(state, isNotNull);
      expect(state!.events.length, 20);
      expect(state.events, sampleEventsPage1);
      expect(state.currentPage, 0);
      expect(state.hasReachedMax, false); // pageSize is 20, got 20
      expect(state.isLoadingNextPage, false);

      verify(mockEventRepository.fetchEvents(page: 0, pageSize: 20)).called(1);
    });

    test('fetchNextPage loads more events and updates state correctly', () async {
      // Arrange: Initial fetch
      when(mockEventRepository.fetchEvents(page: 0, pageSize: 20))
          .thenAnswer((_) async => sampleEventsPage1);
      // Arrange: Next page fetch
      when(mockEventRepository.fetchEvents(page: 1, pageSize: 20))
          .thenAnswer((_) async => sampleEventsPage2);

      final container = createContainer(repository: mockEventRepository);
      // Wait for initial build
      await container.read(eventListProvider.future);

      // Act: Fetch next page
      await container.read(eventListProvider.notifier).fetchNextPage();

      // Assert
      final state = container.read(eventListProvider).value;
      expect(state, isNotNull);
      expect(state!.events.length, 30); // 20 (page1) + 10 (page2)
      expect(state.currentPage, 1);
      expect(state.isLoadingNextPage, false);
      expect(state.hasReachedMax, true); // Page 2 had 10 items, less than pageSize 20

      verify(mockEventRepository.fetchEvents(page: 0, pageSize: 20)).called(1);
      verify(mockEventRepository.fetchEvents(page: 1, pageSize: 20)).called(1);
    });

    test('fetchNextPage does nothing if already loading or max reached', () async {
      // Arrange initial state to be loading next page
      when(mockEventRepository.fetchEvents(page: 0, pageSize: 20))
          .thenAnswer((_) async => sampleEventsPage1);

      final container = createContainer(repository: mockEventRepository);
      await container.read(eventListProvider.future); // Initial load

      // Manually set state to simulate loading or max reached
      final notifier = container.read(eventListProvider.notifier);

      // Case 1: isLoadingNextPage = true
      notifier.state = AsyncData(notifier.state.value!.copyWith(isLoadingNextPage: true));
      await notifier.fetchNextPage();
      verifyNever(mockEventRepository.fetchEvents(page: 1, pageSize: 20)); // Should not call

      // Case 2: hasReachedMax = true
      notifier.state = AsyncData(notifier.state.value!.copyWith(isLoadingNextPage: false, hasReachedMax: true));
      await notifier.fetchNextPage();
      verifyNever(mockEventRepository.fetchEvents(page: 1, pageSize: 20)); // Should not call
    });

    test('handles error when fetching initial events', () async {
      // Arrange
      final exception = Exception('Failed to fetch');
      when(mockEventRepository.fetchEvents(page: 0, pageSize: 20))
          .thenThrow(exception);

      final container = createContainer(repository: mockEventRepository);
      final listener = ProviderListener<AsyncValue<EventListState>>();
      container.listen(eventListProvider, listener, fireImmediately: true);

      // Act: Wait for build to attempt fetch
       // Wait for the future to complete with an error
      await expectLater(container.read(eventListProvider.future), throwsA(exception));

      // Assert
      final state = container.read(eventListProvider);
      expect(state, isA<AsyncError>());
      expect((state as AsyncError).error, exception);

      verify(mockEventRepository.fetchEvents(page: 0, pageSize: 20)).called(1);
    });

    test('handles error when fetching next page', () async {
      // Arrange: Initial successful fetch
      when(mockEventRepository.fetchEvents(page: 0, pageSize: 20))
          .thenAnswer((_) async => sampleEventsPage1);
      // Arrange: Error on next page
      final exception = Exception('Failed to fetch next page');
      when(mockEventRepository.fetchEvents(page: 1, pageSize: 20))
          .thenThrow(exception);

      final container = createContainer(repository: mockEventRepository);
      await container.read(eventListProvider.future); // Initial load

      // Act
      await container.read(eventListProvider.notifier).fetchNextPage();

      // Assert: The overall state should remain AsyncData with the previously loaded data,
      // but the isLoadingNextPage flag should be reset.
      // The error during fetchNextPage is caught within the notifier and doesn't
      // transition the main provider state to AsyncError, but updates flags.
      final state = container.read(eventListProvider).value;
      expect(state, isNotNull);
      expect(state!.events.length, 20); // Still has page 1 data
      expect(state.isLoadingNextPage, false); // Error occurred, so loading stopped
      // A more robust solution might add an error field to EventListState to show a specific error for the page load.
      // For this test, we confirm it didn't add more events and reset loading.

      verify(mockEventRepository.fetchEvents(page: 1, pageSize: 20)).called(1);
    });

    test('refresh re-fetches first page and resets state', () async {
      // Arrange: Initial fetch
      when(mockEventRepository.fetchEvents(page: 0, pageSize: 20))
          .thenAnswer((_) async => sampleEventsPage1);
      // Arrange: Data for refresh
      final refreshedEvents = [Event(id: 'refreshed_1', name: 'Refreshed Event 1', startTime: DateTime.now(), createdAt: DateTime.now(), isPublic: true)];
      when(mockEventRepository.fetchEvents(page: 0, pageSize: 20))
          .thenAnswer((_) async => refreshedEvents); // Called again for refresh

      final container = createContainer(repository: mockEventRepository);
      await container.read(eventListProvider.future); // Initial load

      // Act
      await container.read(eventListProvider.notifier).refresh();

      // Assert
      final state = container.read(eventListProvider).value;
      expect(state, isNotNull);
      expect(state!.events.length, 1);
      expect(state.events, refreshedEvents);
      expect(state.currentPage, 0);
      expect(state.hasReachedMax, true); // refreshedEvents length is 1 < pageSize
      expect(state.isLoadingNextPage, false);

      verify(mockEventRepository.fetchEvents(page: 0, pageSize: 20)).called(2); // Initial + refresh
    });
  });
}

// Helper class for Provider.listen
class ProviderListener<T> {
  final List<T> log = <T>[];
  void call(T? previous, T next) {
    log.add(next);
  }
}
