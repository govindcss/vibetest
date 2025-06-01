import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date formatting

import '../../providers/event_providers.dart';
import '../../models/event.dart';
// Assume a common navigator or router setup, e.g., GoRouter.
// For simplicity, direct navigation is used here, replace with your routing solution.
import 'event_details_screen.dart';

/// A screen that displays a list of events with support for infinite scrolling
/// and pull-to-refresh.
///
/// It uses the [eventListProvider] to fetch and manage the state of events.
class EventsListScreen extends ConsumerStatefulWidget {
  /// Default constructor for EventsListScreen.
  const EventsListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Listener for scroll events to implement infinite scrolling.
  ///
  /// When the user scrolls near the bottom of the list and more events might be available,
  /// it triggers fetching the next page of events via [EventListNotifier.fetchNextPage].
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels; // Use pixels for more accuracy
    // Trigger fetch when user is close to the bottom (e.g., 90% of max scroll)
    if (currentScroll >= (maxScroll * 0.9)) {
      final currentListState = ref.read(eventListProvider).value;
      // Check if not already loading next page and if there's more data
      if (currentListState != null && !currentListState.isLoadingNextPage && !currentListState.hasReachedMax) {
        ref.read(eventListProvider.notifier).fetchNextPage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventListAsyncValue = ref.watch(eventListProvider);

    // Listen for error messages from fetchNextPage and show a SnackBar.
    // This handles errors that don't transition the whole provider to AsyncError.
    ref.listen<AsyncValue<EventListState>>(eventListProvider, (_, next) {
      if (next.value?.errorMessage != null && next.value!.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.value!.errorMessage!)),
        );
        // Consider a way to clear the error message in the state after showing it,
        // e.g., by calling a method on the notifier if you want to avoid re-showing on rebuild.
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Events',
            onPressed: () {
              ref.read(eventListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: eventListAsyncValue.when(
        data: (eventListState) {
          if (eventListState.events.isEmpty && !eventListState.isLoadingNextPage) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No events found.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => ref.read(eventListProvider.notifier).refresh(),
                    child: const Text('Refresh'),
                  )
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(eventListProvider.notifier).refresh(),
            child: ListView.builder(
              controller: _scrollController,
              // Add 1 to itemCount if loading next page to show loading indicator
              itemCount: eventListState.events.length + (eventListState.isLoadingNextPage ? 1 : 0),
              itemBuilder: (context, index) {
                // If it's the last item and we are loading more, show indicator
                if (index == eventListState.events.length && eventListState.isLoadingNextPage) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final Event event = eventListState.events[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  child: ListTile(
                    title: Text(event.name, style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(
                      'Starts: ${DateFormat.yMMMd().add_jm().format(event.startTime.toLocal())}'
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      print('Tapped on event: ${event.name} (ID: ${event.id})');
                      // Navigate to event details screen
                       Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventDetailsScreen(eventId: event.id),
                        ),
                      );
                      // Example with GoRouter: context.push('/event/${event.id}');
                    },
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          print('Error in EventsListScreen UI: $error\n$stackTrace');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Failed to load events: ${error.toString()}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.read(eventListProvider.notifier).refresh(),
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
