import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date formatting

import '../../models/forum_thread.dart';
import '../../providers/forum_providers.dart';
// Assume a common navigator or router setup, e.g., GoRouter.
// For simplicity, direct navigation is used here, replace with your routing solution.
import '../screens/create_forum_thread_screen.dart';
import '../screens/forum_thread_screen.dart';

/// A widget that displays a list of forum threads for a given event.
///
/// It supports infinite scrolling for loading more threads and pull-to-refresh.
/// Users can tap on a thread to navigate to its details or use a FAB to create a new thread.
/// It takes an `eventId` and uses [forumThreadsProvider] to manage and display threads.
class EventForumView extends ConsumerStatefulWidget {
  /// The unique identifier of the event for which to display forum threads.
  final String eventId;

  /// Constructs an [EventForumView].
  /// Requires an [eventId].
  const EventForumView({Key? key, required this.eventId}) : super(key: key);

  @override
  ConsumerState<EventForumView> createState() => _EventForumViewState();
}

class _EventForumViewState extends ConsumerState<EventForumView> {
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

  /// Listener for scroll events to implement infinite scrolling for forum threads.
  ///
  /// When the user scrolls near the bottom, it triggers fetching the next page
  /// via [ForumThreadsNotifier.fetchNextPage].
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= (maxScroll * 0.9)) {
      final currentListState = ref.read(forumThreadsProvider(widget.eventId)).value;
      if (currentListState != null && !currentListState.isLoadingNextPage && !currentListState.hasReachedMax) {
        ref.read(forumThreadsProvider(widget.eventId).notifier).fetchNextPage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final forumThreadsAsyncValue = ref.watch(forumThreadsProvider(widget.eventId));

    // Listen for error messages from fetchNextPage and show a SnackBar.
    ref.listen<AsyncValue<ForumThreadsState>>(forumThreadsProvider(widget.eventId), (_, next) {
      if (next.value?.errorMessage != null && next.value!.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.value!.errorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });

    // This Scaffold is used because EventForumView might be used as a primary view in a tab.
    // If it's always embedded, the Scaffold might be part of the parent screen.
    // For this review, assuming it can be self-contained with its own FAB.
    return Scaffold(
      body: forumThreadsAsyncValue.when(
        data: (threadsState) {
          if (threadsState.threads.isEmpty && !threadsState.isLoadingNextPage) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No forum threads yet. Start a discussion!'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => ref.read(forumThreadsProvider(widget.eventId).notifier).refresh(),
                    child: const Text('Refresh'),
                  )
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(forumThreadsProvider(widget.eventId).notifier).refresh(),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0), // Add padding around the list
              itemCount: threadsState.threads.length + (threadsState.isLoadingNextPage ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == threadsState.threads.length && threadsState.isLoadingNextPage) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final ForumThread thread = threadsState.threads[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  elevation: 2,
                  child: ListTile(
                    title: Text(thread.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Author: ...${thread.userId?.substring(thread.userId!.length - 6) ?? "N/A"}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Last activity: ${DateFormat.yMd().add_jm().format(thread.updatedAt.toLocal())}',
                           style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                       Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ForumThreadScreen(threadId: thread.id),
                        ),
                      );
                      // Example with GoRouter: context.push('/event/${widget.eventId}/forum-thread/${thread.id}');
                    },
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          print('Error in EventForumView UI for event ${widget.eventId}: $error\n$stackTrace');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Failed to load forum threads: ${error.toString()}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.read(forumThreadsProvider(widget.eventId).notifier).refresh(),
                  child: const Text('Try Again'),
                )
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateForumThreadScreen(eventId: widget.eventId),
            ),
          );
          // Example with GoRouter: context.push('/event/${widget.eventId}/create-forum-thread');
        },
        child: const Icon(Icons.add_comment_outlined),
        tooltip: 'Create New Thread',
      ),
    );
  }
}
