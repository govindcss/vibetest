import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For currentUserId

import '../../models/event.dart'; // For Event model
import '../../models/event_user.dart'; // For EventUser model
import '../../providers/event_details_provider.dart';
// Import chat and forum views to embed them
import '../widgets/event_chat_view.dart';
import '../widgets/event_forum_view.dart';

/// A screen that displays detailed information about a specific event.
///
/// It takes an `eventId` as a parameter and uses [eventDetailsProvider]
/// to fetch and display event details, attendee lists, and provides actions
/// like joining/leaving the event or changing its privacy settings (for hosts).
/// It also embeds [EventChatView] and [EventForumView].
class EventDetailsScreen extends ConsumerWidget {
  /// The unique identifier of the event to display.
  final String eventId;

  /// Constructs an [EventDetailsScreen].
  ///
  /// Requires an [eventId] to fetch the relevant event data.
  const EventDetailsScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventDetailsAsyncValue = ref.watch(eventDetailsProvider(eventId));
    // It's good practice to get currentUserId once, rather than multiple times in build method.
    // However, for RLS, Supabase client handles auth state internally for repository calls.
    // For UI logic, it's fine here.
    final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Listen for action error messages from the provider and show a SnackBar.
    ref.listen<AsyncValue<EventDetailsState>>(eventDetailsProvider(eventId), (_, next) {
      if (next.value?.actionErrorMessage != null && next.value!.actionErrorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.value!.actionErrorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
        // Consider adding a method to the notifier to clear the actionErrorMessage
        // after it has been shown, to prevent it from re-appearing on unrelated rebuilds.
      }
    });

    return Scaffold(
      // AppBar title updates based on loaded event name
      appBar: AppBar(
        title: Text(eventDetailsAsyncValue.value?.event?.name ?? 'Event Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Event Details',
            onPressed: () {
              ref.read(eventDetailsProvider(eventId).notifier).refresh();
            },
          ),
        ],
      ),
      body: eventDetailsAsyncValue.when(
        data: (detailsState) {
          final Event? event = detailsState.event;
          if (event == null) {
            // This case might occur if the event ID is invalid or event was deleted.
            return const Center(child: Text('Event not found.'));
          }

          // UI elements controlled by user's relation to the event
          final bool isHost = detailsState.isCurrentUserHost;
          final bool isAttendee = detailsState.isCurrentUserAttendee;
          final bool isLoadingAction = detailsState.isLoadingAction;

          return DefaultTabController(
            length: 3, // Details, Chat, Forum
            child: Column(
              children: [
                _buildEventHeader(context, event, isHost, isAttendee, isLoadingAction, ref),
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.info_outline), text: 'Details'),
                    Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
                    Tab(icon: Icon(Icons.forum_outlined), text: 'Forum'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildDetailsTabView(context, event, detailsState.attendees),
                      EventChatView(eventId: eventId),
                      EventForumView(eventId: eventId),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          print('Error in EventDetailsScreen UI for event $eventId: $error\n$stackTrace');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Failed to load event details: ${error.toString()}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.read(eventDetailsProvider(eventId).notifier).refresh(),
                  child: const Text('Try Again'),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds the header section of the event details screen.
  /// Contains event name, times, and action buttons (join/leave, privacy toggle).
  Widget _buildEventHeader(
    BuildContext context,
    Event event,
    bool isHost,
    bool isAttendee,
    bool isLoadingAction,
    WidgetRef ref,
  ) {
    final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Starts: ${DateFormat.yMMMMEEEEd().add_jm().format(event.startTime.toLocal())}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (event.endTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Ends:   ${DateFormat.yMMMMEEEEd().add_jm().format(event.endTime!.toLocal())}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          const SizedBox(height: 16),
          if (currentUserId != null) ...[
            if (isLoadingAction)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(),
              ))
            else ...[
              if (isHost)
                SwitchListTile(
                  title: const Text('Event is Public'),
                  value: event.isPublic,
                  onChanged: (bool value) {
                    ref.read(eventDetailsProvider(eventId).notifier).updateEventPrivacy(value);
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              if (!isAttendee && event.isPublic) // Users can only join public events directly
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Join Event'),
                  onPressed: () => ref.read(eventDetailsProvider(eventId).notifier).joinEvent(),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 36)),
                ),
              if (isAttendee && !isHost) // Host is an attendee by definition, avoid showing both buttons
                ElevatedButton.icon(
                  icon: const Icon(Icons.exit_to_app_outlined),
                  label: const Text('Leave Event'),
                  onPressed: () => ref.read(eventDetailsProvider(eventId).notifier).leaveEvent(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[400],
                    minimumSize: const Size(double.infinity, 36)
                  ),
                ),
            ],
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  /// Builds the "Details" tab view, showing event description, location, and attendees.
  Widget _buildDetailsTabView(BuildContext context, Event event, List<EventUser> attendees) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.description != null && event.description!.isNotEmpty) ...[
            Text('Description:', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(event.description!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],
          if (event.locationText != null && event.locationText!.isNotEmpty) ...[
            Text('Location:', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(event.locationText!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],
          Text('Status: ${event.isPublic ? "Public" : "Private"}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          Text('Attendees (${attendees.length}):', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (attendees.isEmpty)
            const Text('No attendees yet. Be the first to join!')
          else
            ListView.builder(
              shrinkWrap: true, // Important for ListView inside SingleChildScrollView
              physics: const NeverScrollableScrollPhysics(), // Disable scrolling for inner ListView
              itemCount: attendees.length,
              itemBuilder: (context, index) {
                final EventUser attendee = attendees[index];
                // In a real app, you'd fetch profile info (e.g., username, avatar) for the attendee.userId
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(attendee.userId.substring(0, 2).toUpperCase())),
                    title: Text('User ID: ...${attendee.userId.substring(attendee.userId.length - 6)}'),
                    subtitle: Text('Role: ${attendee.role}'),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
