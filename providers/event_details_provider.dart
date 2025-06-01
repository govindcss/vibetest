import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Required for Supabase.instance.client.auth
import '../models/event.dart';
import '../models/event_user.dart';
import '../repositories/event_repository.dart';

// Assuming eventRepositoryProvider is already defined (e.g., in event_providers.dart)
// If not, define it here or import it.
// final eventRepositoryProvider = Provider<EventRepository>((ref) => EventRepository());

class EventDetailsState {
  final Event? event;
  final List<EventUser> attendees;
  final bool isCurrentUserAttendee;
  final bool isCurrentUserHost;
  final bool isLoading; // For actions like join/leave/update
  final String? errorMessage; // For errors from actions

  EventDetailsState({
    this.event,
    this.attendees = const [],
    this.isCurrentUserAttendee = false,
    this.isCurrentUserHost = false,
    this.isLoading = false,
    this.errorMessage,
  });

  EventDetailsState copyWith({
    Event? event,
    List<EventUser>? attendees,
    bool? isCurrentUserAttendee,
    bool? isCurrentUserHost,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return EventDetailsState(
      event: event ?? this.event,
      attendees: attendees ?? this.attendees,
      isCurrentUserAttendee: isCurrentUserAttendee ?? this.isCurrentUserAttendee,
      isCurrentUserHost: isCurrentUserHost ?? this.isCurrentUserHost,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class EventDetailsNotifier extends FamilyAsyncNotifier<EventDetailsState, String> {
  String get _eventId => arg;
  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  Future<EventDetailsState> _fetchData() async {
    final repository = ref.read(eventRepositoryProvider);
    final event = await repository.fetchEventDetails(_eventId);
    final attendees = await repository.fetchEventAttendees(_eventId);

    bool isAttendee = false;
    bool isHost = false;
    if (_currentUserId != null) {
      isAttendee = attendees.any((att) => att.userId == _currentUserId);
      if (event.createdBy == _currentUserId) {
        isHost = true;
      } else {
        final currentUserAsEventUser = attendees.firstWhere(
            (att) => att.userId == _currentUserId,
            orElse: () => EventUser(eventId: _eventId, userId: '', joinedAt: DateTime.now(), role: '')); // Dummy if not found
        if (currentUserAsEventUser.role == 'host') {
          isHost = true;
        }
      }
    }

    return EventDetailsState(
      event: event,
      attendees: attendees,
      isCurrentUserAttendee: isAttendee,
      isCurrentUserHost: isHost,
    );
  }

  @override
  Future<EventDetailsState> build(String eventId) async {
    return _fetchData();
  }

  Future<void> joinEvent() async {
    final currentState = state.value;
    if (currentState == null || _currentUserId == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true, clearErrorMessage: true));
    try {
      await ref.read(eventRepositoryProvider).joinEvent(_eventId);
      // Refresh data
      final refreshedData = await _fetchData();
      state = AsyncData(refreshedData.copyWith(isLoading: false));
    } catch (e) {
      state = AsyncData(currentState.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> leaveEvent() async {
    final currentState = state.value;
    if (currentState == null || _currentUserId == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true, clearErrorMessage: true));
    try {
      await ref.read(eventRepositoryProvider).leaveEvent(_eventId);
      // Refresh data
      final refreshedData = await _fetchData();
      state = AsyncData(refreshedData.copyWith(isLoading: false));
    } catch (e) {
      state = AsyncData(currentState.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> updateEventPrivacy(bool isPublic) async {
    final currentState = state.value;
    if (currentState == null || currentState.event == null) return;
     // Ensure only host can do this (though RLS should also enforce)
    if (!currentState.isCurrentUserHost) {
        state = AsyncData(currentState.copyWith(errorMessage: "Only hosts can change privacy."));
        return;
    }

    state = AsyncData(currentState.copyWith(isLoading: true, clearErrorMessage: true));
    try {
      await ref.read(eventRepositoryProvider).updateEventPrivacy(_eventId, isPublic);
      // Refresh data
      final refreshedData = await _fetchData();
      state = AsyncData(refreshedData.copyWith(isLoading: false));
    } catch (e) {
      state = AsyncData(currentState.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await _fetchData());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final eventDetailsProvider = AsyncNotifierProviderFamily<EventDetailsNotifier, EventDetailsState, String>(() {
  return EventDetailsNotifier();
});

// Provider to easily check if the current user is an attendee for the given eventId
final isCurrentUserAttendeeProvider = Provider.family<bool, String>((ref, eventId) {
  final detailsState = ref.watch(eventDetailsProvider(eventId));
  return detailsState.value?.isCurrentUserAttendee ?? false;
});

// Provider to easily check if the current user is a host for the given eventId
final isCurrentUserHostProvider = Provider.family<bool, String>((ref, eventId) {
  final detailsState = ref.watch(eventDetailsProvider(eventId));
  return detailsState.value?.isCurrentUserHost ?? false;
});

// Provider to get the event object itself, if loaded
final currentEventProvider = Provider.family<Event?, String>((ref, eventId) {
  final detailsState = ref.watch(eventDetailsProvider(eventId));
  return detailsState.value?.event;
});
