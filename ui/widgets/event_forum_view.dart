import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date formatting

import '../../models/forum_thread.dart';
import '../../providers/forum_providers.dart';
// Assume GoRouter or similar is used for navigation, replace with actual navigation calls
// import 'package:go_router/go_router.dart';
import '../screens/create_forum_thread_screen.dart'; // For navigation
import '../screens/forum_thread_screen.dart';       // For navigation


class EventForumView extends ConsumerStatefulWidget {
  final String eventId;

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

  void _onScroll() {
    if (_isBottom) {
      final notifier = ref.read(forumThreadsProvider(widget.eventId).notifier);
      final currentListState = ref.read(forumThreadsProvider(widget.eventId)).value;
      if (currentListState != null && !currentListState.isLoadingNextPage && !currentListState.hasReachedMax) {
        notifier.fetchNextPage();
      }
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final forumThreadsAsyncValue = ref.watch(forumThreadsProvider(widget.eventId));

    ref.listen<AsyncValue<ForumThreadsState>>(forumThreadsProvider(widget.eventId), (_, next) {
      if (next.value?.errorMessage != null && next.value!.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.value!.errorMessage!)),
        );
      }
    });

    return Scaffold(
      body: forumThreadsAsyncValue.when(
        data: (threadsState) {
          if (threadsState.threads.isEmpty && !threadsState.isLoadingNextPage) {
            return const Center(child: Text('No forum threads yet. Start a discussion!'));
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(forumThreadsProvider(widget.eventId).notifier).refresh(),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: threadsState.threads.length + (threadsState.isLoadingNextPage ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == threadsState.threads.length && threadsState.isLoadingNextPage) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ));
                }
                final ForumThread thread = threadsState.threads[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(thread.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User: ${thread.userId?.substring(0, 6) ?? "N/A"}...'), // Show part of user ID
                        Text('Last activity: ${DateFormat.yMd().add_jm().format(thread.updatedAt.toLocal())}'),
                      ],
                    ),
                    onTap: () {
                      // Using direct navigation for simplicity. Replace with GoRouter or your routing solution.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ForumThreadScreen(threadId: thread.id),
                        ),
                      );
                      // Example with GoRouter: context.push('/forum-thread/${thread.id}');
                    },
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          print('Error in EventForumView: $error\n$stackTrace');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Failed to load forum threads: ${error.toString()}'),
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
          // Using direct navigation. Replace with GoRouter.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateForumThreadScreen(eventId: widget.eventId),
            ),
          );
          // Example with GoRouter: context.push('/create-forum-thread/${widget.eventId}');
        },
        child: const Icon(Icons.add_comment_outlined),
        tooltip: 'Create New Thread',
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
