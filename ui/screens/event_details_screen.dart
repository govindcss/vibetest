import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/event.dart';
import '../../models/event_user.dart';
import '../../providers/event_details_provider.dart';
// Assuming eventRepositoryProvider is in event_providers.dart or accessible
// We need it for the EventDetailsNotifier.
import '../../providers/event_providers.dart';


class EventDetailsScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailsScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventDetailsAsyncValue = ref.watch(eventDetailsProvider(eventId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Listen for error messages from actions
    ref.listen<AsyncValue<EventDetailsState>>(eventDetailsProvider(eventId), (_, next) {
      if (next.value?.errorMessage != null && next.value!.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.value!.errorMessage!)),
        );
        // Consider clearing the error message in the state after showing it
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: eventDetailsAsyncValue.when(
          data: (details) => Text(details.event?.name ?? 'Event Details'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(eventDetailsProvider(eventId).notifier).refresh();
            },
          ),
        ],
      ),
      body: eventDetailsAsyncValue.when(
        data: (details) {
          final event = details.event;
          if (event == null) {
            return const Center(child: Text('Event not found.'));
          }

          final attendees = details.attendees;
          final bool isHost = details.isCurrentUserHost;
          final bool isAttendee = details.isCurrentUserAttendee;
          final bool isLoadingAction = details.isLoading;


          return RefreshIndicator(
            onRefresh: () => ref.read(eventDetailsProvider(eventId).notifier).refresh(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.name, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Starts: ${DateFormat.yMMMd().add_jm().format(event.startTime)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (event.endTime != null)
                    Text(
                      'Ends: ${DateFormat.yMMMd().add_jm().format(event.endTime!)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  const SizedBox(height: 16),
                  if (event.description != null && event.description!.isNotEmpty) ...[
                    Text('Description:', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(event.description!),
                    const SizedBox(height: 16),
                  ],
                  if (event.locationText != null && event.locationText!.isNotEmpty) ...[
                    Text('Location:', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(event.locationText!),
                    const SizedBox(height: 16),
                  ],

                  Text('Status: ${event.isPublic ? "Public" : "Private"}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),

                  if (currentUserId != null) ...[
                    if (isLoadingAction)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      if (isHost)
                        SwitchListTile(
                          title: const Text('Event is Public'),
                          value: event.isPublic,
                          onChanged: (bool value) {
                            ref.read(eventDetailsProvider(eventId).notifier).updateEventPrivacy(value);
                          },
                        ),
                      if (!isAttendee && event.isPublic) // Or other logic for allowing join
                        ElevatedButton(
                          onPressed: () {
                            ref.read(eventDetailsProvider(eventId).notifier).joinEvent();
                          },
                          child: const Text('Join Event'),
                        ),
                      if (isAttendee)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            ref.read(eventDetailsProvider(eventId).notifier).leaveEvent();
                          },
                          child: const Text('Leave Event'),
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],

                  Text('Attendees (${attendees.length}):', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (attendees.isEmpty)
                    const Text('No attendees yet.')
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(), // Disable scrolling within SingleChildScrollView
                      itemCount: attendees.length,
                      itemBuilder: (context, index) {
                        final EventUser attendee = attendees[index];
                        return ListTile(
                          title: Text('User ID: ${attendee.userId}'), // Replace with profile info if available
                          subtitle: Text('Role: ${attendee.role}'),
                          // leading: CircleAvatar(child: Text(attendee.userId.substring(0,2))),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          print('Error in EventDetailsScreen for $eventId: $error\n$stackTrace');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Failed to load event details: $error'),
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
}
