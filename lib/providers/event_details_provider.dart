import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Required for Supabase.instance.client.auth
import '../models/event.dart';
import '../models/event_user.dart';
import '../repositories/event_repository.dart';
// Assuming eventRepositoryProvider is defined in event_providers.dart
import 'event_providers.dart';

/// Represents the state for the event details screen.
///
/// This includes the [Event] object itself, the list of [EventUser] attendees,
/// flags indicating the current user's status (attendee, host),
/// loading state for actions (like join/leave), and any error messages from these actions.
class EventDetailsState {
  /// The details of the event. Null if not yet loaded or not found.
  final Event? event;

  /// The list of users attending the event.
  final List<EventUser> attendees;

  /// True if the current authenticated user is an attendee of this event.
  final bool isCurrentUserAttendee;

  /// True if the current authenticated user is a host of this event (creator or 'host' role).
  final bool isCurrentUserHost;

  /// True if an action (join, leave, update privacy) is currently in progress.
  final bool isLoadingAction; // Renamed from isLoading for clarity

  /// An optional error message if an error occurred during an action.
  final String? actionErrorMessage; // Renamed from errorMessage for clarity

  /// Constructs an [EventDetailsState].
  EventDetailsState({
    this.event,
    this.attendees = const [],
    this.isCurrentUserAttendee = false,
    this.isCurrentUserHost = false,
    this.isLoadingAction = false,
    this.actionErrorMessage,
  });

  /// Creates a copy of this [EventDetailsState] instance with specified fields updated.
  EventDetailsState copyWith({
    Event? event,
    List<EventUser>? attendees,
    bool? isCurrentUserAttendee,
    bool? isCurrentUserHost,
    bool? isLoadingAction,
    String? actionErrorMessage,
    bool clearActionErrorMessage = false,
  }) {
    return EventDetailsState(
      event: event ?? this.event,
      attendees: attendees ?? this.attendees,
      isCurrentUserAttendee: isCurrentUserAttendee ?? this.isCurrentUserAttendee,
      isCurrentUserHost: isCurrentUserHost ?? this.isCurrentUserHost,
      isLoadingAction: isLoadingAction ?? this.isLoadingAction,
      actionErrorMessage: clearActionErrorMessage ? null : actionErrorMessage ?? this.actionErrorMessage,
    );
  }
}

/// Manages the state for a single event's details, including its attendees
/// and actions like joining/leaving the event or updating its privacy.
///
/// This notifier is a [FamilyAsyncNotifier], taking an `eventId` (String) as an argument
/// to fetch and manage data for a specific event.
class EventDetailsNotifier extends FamilyAsyncNotifier<EventDetailsState, String> {
  /// The ID of the event this notifier is managing. Accessed via `arg`.
  String get _eventId => arg;

  /// The ID of the current authenticated user, if available.
  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  /// Helper method to fetch all necessary data for the event details state.
  /// This includes the event itself and its attendees.
  /// It also calculates if the current user is an attendee or host.
  Future<EventDetailsState> _fetchData() async {
    final repository = ref.read(eventRepositoryProvider);
    // Fetch event details and attendees concurrently for faster loading.
    final results = await Future.wait([
      repository.fetchEventDetails(_eventId),
      repository.fetchEventAttendees(_eventId),
    ]);

    final event = results[0] as Event;
    final attendees = results[1] as List<EventUser>;

    bool isAttendee = false;
    bool isHost = false;

    if (_currentUserId != null) {
      isAttendee = attendees.any((att) => att.userId == _currentUserId);
      if (event.createdBy == _currentUserId) {
        isHost = true;
      } else {
        // Check if the user has a 'host' role in event_users, only if not the creator.
        // This avoids re-checking if already identified as host via created_by.
        final currentUserInEvent = attendees.firstWhere(
            (att) => att.userId == _currentUserId,
            orElse: () => EventUser(eventId: _eventId, userId: '', joinedAt: DateTime.now(), role: '')); // Dummy if not found
        if (currentUserInEvent.role == 'host') {
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

  /// Fetches the initial event details and attendee data when the provider is first built.
  @override
  Future<EventDetailsState> build(String eventId) async {
    // `arg` (eventId) is automatically available here.
    return _fetchData();
  }

  /// Allows the current user to join the event.
  ///
  /// Sets [EventDetailsState.isLoadingAction] to true during the operation.
  /// On success, refreshes the event data. On failure, sets [EventDetailsState.actionErrorMessage].
  Future<void> joinEvent() async {
    final currentState = state.value;
    if (currentState == null || _currentUserId == null) return; // Should not happen if data is loaded

    state = AsyncData(currentState.copyWith(isLoadingAction: true, clearActionErrorMessage: true));
    try {
      await ref.read(eventRepositoryProvider).joinEvent(_eventId);
      // Refresh all data to reflect changes (e.g., attendee list, user status)
      final refreshedData = await _fetchData();
      state = AsyncData(refreshedData.copyWith(isLoadingAction: false));
    } catch (e) {
      state = AsyncData(currentState.copyWith(isLoadingAction: false, actionErrorMessage: e.toString()));
    }
  }

  /// Allows the current user to leave the event.
  ///
  /// Sets [EventDetailsState.isLoadingAction] to true during the operation.
  /// On success, refreshes the event data. On failure, sets [EventDetailsState.actionErrorMessage].
  Future<void> leaveEvent() async {
    final currentState = state.value;
    if (currentState == null || _currentUserId == null) return;

    state = AsyncData(currentState.copyWith(isLoadingAction: true, clearActionErrorMessage: true));
    try {
      await ref.read(eventRepositoryProvider).leaveEvent(_eventId);
      final refreshedData = await _fetchData();
      state = AsyncData(refreshedData.copyWith(isLoadingAction: false));
    } catch (e) {
      state = AsyncData(currentState.copyWith(isLoadingAction: false, actionErrorMessage: e.toString()));
    }
  }

  /// Updates the privacy status of the event.
  ///
  /// This action should typically only be available to event hosts.
  /// Sets [EventDetailsState.isLoadingAction] to true during the operation.
  /// On success, refreshes the event data. On failure, sets [EventDetailsState.actionErrorMessage].
  ///
  /// - [isPublic]: The new public status for the event.
  Future<void> updateEventPrivacy(bool isPublic) async {
    final currentState = state.value;
    if (currentState == null || currentState.event == null) return;

    // Client-side check, RLS provides server-side enforcement.
    if (!currentState.isCurrentUserHost) {
        state = AsyncData(currentState.copyWith(actionErrorMessage: "Only hosts can change event privacy."));
        return;
    }

    state = AsyncData(currentState.copyWith(isLoadingAction: true, clearActionErrorMessage: true));
    try {
      await ref.read(eventRepositoryProvider).updateEventPrivacy(_eventId, isPublic);
      final refreshedData = await _fetchData();
      state = AsyncData(refreshedData.copyWith(isLoadingAction: false));
    } catch (e) {
      state = AsyncData(currentState.copyWith(isLoadingAction: false, actionErrorMessage: e.toString()));
    }
  }

  /// Refreshes all data for the event details screen.
  ///
  /// The provider will be in a loading state during the refresh.
  Future<void> refresh() async {
    state = const AsyncLoading(); // Set to loading state
    try {
      state = AsyncData(await _fetchData());
    } catch (e, st) {
      // If refresh fails, transition the provider to an error state.
      state = AsyncError(e, st);
    }
  }
}

/// Provider for [EventDetailsNotifier].
///
/// This provider is a family that takes an `eventId` (String) as an argument.
/// It's used by UI widgets to access and manage the state for a specific event's details.
final eventDetailsProvider = AsyncNotifierProviderFamily<EventDetailsNotifier, EventDetailsState, String>(() {
  return EventDetailsNotifier();
});

// --- Helper providers for easier UI access to specific boolean states ---

/// A family provider that returns whether the current user is an attendee of the specified event.
///
/// - Argument: `eventId` (String).
/// Returns `true` if the user is an attendee, `false` otherwise. Defaults to `false` if data is not loaded.
final isCurrentUserAttendeeProvider = Provider.family<bool, String>((ref, eventId) {
  // Watch the main details provider for the given eventId
  final detailsState = ref.watch(eventDetailsProvider(eventId));
  // Return the specific boolean from the state, or false if state is not yet data.
  return detailsState.value?.isCurrentUserAttendee ?? false;
});

/// A family provider that returns whether the current user is a host of the specified event.
///
/// - Argument: `eventId` (String).
/// Returns `true` if the user is a host, `false` otherwise. Defaults to `false` if data is not loaded.
final isCurrentUserHostProvider = Provider.family<bool, String>((ref, eventId) {
  final detailsState = ref.watch(eventDetailsProvider(eventId));
  return detailsState.value?.isCurrentUserHost ?? false;
});

/// A family provider that returns the [Event] object for the specified event ID, if loaded.
///
/// - Argument: `eventId` (String).
/// Returns the [Event] object or `null` if data is not loaded or the event is not found.
final currentEventProvider = Provider.family<Event?, String>((ref, eventId) {
  final detailsState = ref.watch(eventDetailsProvider(eventId));
  return detailsState.value?.event;
});
