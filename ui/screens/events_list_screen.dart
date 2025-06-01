import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date formatting

import '../../providers/event_providers.dart';
import '../../models/event.dart';

class EventsListScreen extends ConsumerStatefulWidget {
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

  void _onScroll() {
    if (_isBottom) {
      final notifier = ref.read(eventListProvider.notifier);
      // Access state value carefully if needed, but here just calling fetchNextPage
      final currentListState = ref.read(eventListProvider).value;
      if (currentListState != null && !currentListState.isLoadingNextPage && !currentListState.hasReachedMax) {
        notifier.fetchNextPage();
      }
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // Trigger loading a bit before reaching the absolute end
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final eventListAsyncValue = ref.watch(eventListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(eventListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: eventListAsyncValue.when(
        data: (eventListState) {
          if (eventListState.events.isEmpty && !eventListState.isLoadingNextPage) {
            return const Center(child: Text('No events found.'));
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(eventListProvider.notifier).refresh(),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: eventListState.events.length + (eventListState.isLoadingNextPage ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == eventListState.events.length && eventListState.isLoadingNextPage) {
                  return const Center(child: CircularProgressIndicator());
                }
                final Event event = eventListState.events[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(event.name),
                    subtitle: Text(
                      'Starts: ${DateFormat.yMMMd().add_jm().format(event.startTime)}'
                    ),
                    onTap: () {
                      // Placeholder for navigation
                      print('Tapped on event: ${event.name} (ID: ${event.id})');
                      // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailScreen(eventId: event.id)));
                    },
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          print('Error in EventsListScreen: $error');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Failed to load events: $error'),
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

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}
