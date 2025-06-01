import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../repositories/event_repository.dart';

// Provider for the EventRepository
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository();
});

class EventListState {
  final List<Event> events;
  final bool isLoadingNextPage;
  final bool hasReachedMax;
  final int currentPage;

  EventListState({
    this.events = const [],
    this.isLoadingNextPage = false,
    this.hasReachedMax = false,
    this.currentPage = 0,
  });

  EventListState copyWith({
    List<Event>? events,
    bool? isLoadingNextPage,
    bool? hasReachedMax,
    int? currentPage,
  }) {
    return EventListState(
      events: events ?? this.events,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class EventListNotifier extends AsyncNotifier<EventListState> {
  static const int _pageSize = 20;

  @override
  Future<EventListState> build() async {
    // Initial fetch
    final initialEvents = await _fetchPage(0);
    return EventListState(
      events: initialEvents,
      currentPage: 0,
      hasReachedMax: initialEvents.length < _pageSize,
    );
  }

  Future<List<Event>> _fetchPage(int page) async {
    final repository = ref.read(eventRepositoryProvider);
    try {
      final newEvents = await repository.fetchEvents(page: page, pageSize: _pageSize);
      return newEvents;
    } catch (e) {
      // Handle error appropriately, maybe update state with error
      print("Error fetching page $page: $e");
      throw e; // Rethrow to let AsyncNotifier handle error state
    }
  }

  Future<void> fetchNextPage() async {
    // Ensure previous state is data, not error/loading for the main list
    final previousState = state.value;
    if (previousState == null || previousState.isLoadingNextPage || previousState.hasReachedMax) {
      return;
    }

    state = AsyncData(previousState.copyWith(isLoadingNextPage: true));

    try {
      final nextPage = previousState.currentPage + 1;
      final newEvents = await _fetchPage(nextPage);

      state = AsyncData(previousState.copyWith(
        events: [...previousState.events, ...newEvents],
        currentPage: nextPage,
        isLoadingNextPage: false,
        hasReachedMax: newEvents.length < _pageSize,
      ));
    } catch (e, st) {
      print("Error fetching next page: $e");
      // If main list was loaded, keep it and show error for next page,
      // or transition main state to error. For simplicity here,
      // we revert loadingNextPage and let main state be.
      // A more robust solution might add an error field to EventListState.
      state = AsyncData(previousState.copyWith(isLoadingNextPage: false));
      // Optionally, you could rethrow to make the whole provider go into error state:
      // state = AsyncError(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final initialEvents = await _fetchPage(0);
      state = AsyncData(EventListState(
        events: initialEvents,
        currentPage: 0,
        hasReachedMax: initialEvents.length < _pageSize,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final eventListProvider = AsyncNotifierProvider<EventListNotifier, EventListState>(() {
  return EventListNotifier();
});
