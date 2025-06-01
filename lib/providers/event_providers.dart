import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../repositories/event_repository.dart';

/// Provides an instance of [EventRepository].
///
/// This provider is used by other providers (like [eventListProvider]) to access
/// the repository for fetching and manipulating event data.
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository();
  // If EventRepository had dependencies, they would be resolved here using ref.watch or ref.read.
});

/// Represents the state for the list of events, including pagination details.
class EventListState {
  /// The current list of fetched events.
  final List<Event> events;

  /// Indicates if the next page of events is currently being loaded.
  final bool isLoadingNextPage;

  /// Indicates if all available events have been fetched (no more pages).
  final bool hasReachedMax;

  /// The current page number that has been fetched (0-indexed).
  final int currentPage;

  /// An optional error message if an error occurred during fetching.
  final String? errorMessage;


  /// Constructs an [EventListState].
  EventListState({
    this.events = const [],
    this.isLoadingNextPage = false,
    this.hasReachedMax = false,
    this.currentPage = 0,
    this.errorMessage,
  });

  /// Creates a copy of this [EventListState] instance with specified fields updated.
  EventListState copyWith({
    List<Event>? events,
    bool? isLoadingNextPage,
    bool? hasReachedMax,
    int? currentPage,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return EventListState(
      events: events ?? this.events,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      currentPage: currentPage ?? this.currentPage,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

/// Manages the state of the paginated list of events.
///
/// This notifier handles fetching the initial list of events and subsequent pages
/// when requested (e.g., for infinite scrolling). It uses [EventRepository]
/// to fetch data.
class EventListNotifier extends AsyncNotifier<EventListState> {
  /// The number of events to fetch per page.
  static const int _pageSize = 20;

  /// Fetches the initial page of events when the provider is first built.
  ///
  /// Returns an [EventListState] containing the first page of events.
  /// If fetching fails, the provider will be in an error state.
  @override
  Future<EventListState> build() async {
    // Initial fetch for page 0
    final initialEvents = await _fetchPage(0);
    return EventListState(
      events: initialEvents,
      currentPage: 0,
      hasReachedMax: initialEvents.length < _pageSize,
    );
  }

  /// Helper method to fetch a specific page of events.
  Future<List<Event>> _fetchPage(int page) async {
    final repository = ref.read(eventRepositoryProvider);
    try {
      final newEvents = await repository.fetchEvents(page: page, pageSize: _pageSize);
      return newEvents;
    } catch (e) {
      // The error will be caught by the AsyncNotifier and reflected in its state.
      print("Error fetching page $page in EventListNotifier: $e");
      throw e;
    }
  }

  /// Fetches the next page of events.
  ///
  /// Updates the state with the newly fetched events appended to the existing list.
  /// Sets [EventListState.isLoadingNextPage] to true while fetching and updates
  /// [EventListState.hasReachedMax] and [EventListState.currentPage] accordingly.
  /// If an error occurs, [EventListState.errorMessage] is set, but the provider
  /// itself remains in a data state with the previously loaded events.
  Future<void> fetchNextPage() async {
    // Access the current state's value directly.
    // Ensure that the current state is data and not error/loading for the main list.
    final previousStateValue = state.value;
    if (previousStateValue == null || previousStateValue.isLoadingNextPage || previousStateValue.hasReachedMax) {
      return; // Do nothing if already loading, max reached, or if current state is error/loading
    }

    // Set loading state for the next page
    state = AsyncData(previousStateValue.copyWith(isLoadingNextPage: true, clearErrorMessage: true));

    try {
      final nextPage = previousStateValue.currentPage + 1;
      final newEvents = await _fetchPage(nextPage);

      state = AsyncData(previousStateValue.copyWith(
        events: [...previousStateValue.events, ...newEvents],
        currentPage: nextPage,
        isLoadingNextPage: false,
        hasReachedMax: newEvents.length < _pageSize,
      ));
    } catch (e, st) {
      print("Error fetching next page in EventListNotifier: $e");
      // If fetching next page fails, keep existing data and update error message.
      // The main provider state remains AsyncData.
      state = AsyncData(previousStateValue.copyWith(
        isLoadingNextPage: false,
        errorMessage: e.toString(),
      ));
      // Optionally, to make the whole provider go into error state:
      // state = AsyncError(e, st);
      // However, for pagination, usually, we want to keep the old data visible.
    }
  }

  /// Refreshes the list of events by fetching the first page again.
  ///
  /// Resets the pagination state and updates the list with fresh data.
  /// The provider will be in a loading state during the refresh.
  Future<void> refresh() async {
    state = const AsyncLoading(); // Set to loading state
    try {
      final initialEvents = await _fetchPage(0);
      state = AsyncData(EventListState(
        events: initialEvents,
        currentPage: 0,
        hasReachedMax: initialEvents.length < _pageSize,
      ));
    } catch (e, st) {
      // If refresh fails, transition the provider to an error state.
      state = AsyncError(e, st);
    }
  }
}

/// Provider for [EventListNotifier].
///
/// This provider is used by UI widgets to access and manage the list of events.
/// It automatically handles loading, error, and data states for the event list.
final eventListProvider = AsyncNotifierProvider<EventListNotifier, EventListState>(() {
  return EventListNotifier();
});
