import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:supabase_flutter/supabase_flutter.dart'; // For currentUserId

import '../../models/forum_thread.dart';
import '../../models/forum_reply.dart';
import '../../providers/forum_providers.dart';

/// A screen that displays the details of a single forum thread, including its
/// initial content and a list of replies.
///
/// It supports infinite scrolling for replies and allows users to post new replies.
/// Takes a `threadId` and uses [forumThreadDetailsProvider] to manage and display data.
class ForumThreadScreen extends ConsumerStatefulWidget {
  /// The unique identifier of the forum thread to display.
  final int threadId;

  /// Constructs a [ForumThreadScreen].
  /// Requires a [threadId].
  const ForumThreadScreen({Key? key, required this.threadId}) : super(key: key);

  @override
  ConsumerState<ForumThreadScreen> createState() => _ForumThreadScreenState();
}

class _ForumThreadScreenState extends ConsumerState<ForumThreadScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _replyController = TextEditingController();
  // Local state to manage the enabling/disabling of the send button,
  // distinct from the provider's isPostingReply for immediate UI feedback.
  bool _isAttemptingPost = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  /// Listener for scroll events to implement infinite scrolling for replies.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= (maxScroll * 0.9)) {
      final currentDetailsState = ref.read(forumThreadDetailsProvider(widget.threadId)).value;
      if (currentDetailsState != null && !currentDetailsState.isLoadingNextRepliesPage && !currentDetailsState.hasReachedMaxReplies) {
        ref.read(forumThreadDetailsProvider(widget.threadId).notifier).fetchNextRepliesPage();
      }
    }
  }

  /// Handles posting a new reply.
  ///
  /// Calls the `addReply` method on the [ForumThreadDetailsNotifier].
  /// Manages local `_isAttemptingPost` state for UI feedback.
  Future<void> _postReply() async {
    if (_replyController.text.trim().isEmpty || _isAttemptingPost) return;

    setState(() { _isAttemptingPost = true; });

    try {
      await ref.read(forumThreadDetailsProvider(widget.threadId).notifier).addReply(_replyController.text.trim());
      _replyController.clear();
      // After successful reply, scroll to bottom to see the new message.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
             _scrollController.animateTo(
                _scrollController.position.maxScrollExtent + 50, // Ensure it goes to very bottom
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
        }
      });
    } catch (e) {
      // Error is already handled by the provider which updates its errorMessage.
      // The listener below will show the SnackBar.
      // No need to show another SnackBar here unless it's a different error.
    } finally {
       if (mounted) {
        setState(() { _isAttemptingPost = false; });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadDetailsAsyncValue = ref.watch(forumThreadDetailsProvider(widget.threadId));
    final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Listen for error messages from the provider (e.g., if addReply fails)
    ref.listen<AsyncValue<ForumThreadDetailsState>>(forumThreadDetailsProvider(widget.threadId), (_, next) {
      if (next.value?.errorMessage != null && next.value!.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.value!.errorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      // Sync local _isAttemptingPost if provider's isPostingReply changes due to an error.
      // This ensures the button re-enables if the provider caught an error during the post.
      final bool providerIsPosting = next.value?.isPostingReply ?? false;
      if (_isAttemptingPost && !providerIsPosting && next.value?.errorMessage != null) {
         if (mounted) {
           setState(() { _isAttemptingPost = false; });
         }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          threadDetailsAsyncValue.value?.threadDetails?.title ?? 'Thread',
          overflow: TextOverflow.ellipsis,
        ),
         actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Thread',
            onPressed: () {
              ref.read(forumThreadDetailsProvider(widget.threadId).notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: threadDetailsAsyncValue.when(
              data: (detailsState) {
                final ForumThread? thread = detailsState.threadDetails;
                if (thread == null) {
                  return const Center(child: Text('Thread not found.'));
                }

                final List<ForumReply> replies = detailsState.replies;

                return RefreshIndicator(
                  onRefresh: () => ref.read(forumThreadDetailsProvider(widget.threadId).notifier).refresh(),
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      _buildThreadContentView(context, thread),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Text(
                            'Replies (${replies.length})',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (replies.isEmpty && !detailsState.isLoadingNextRepliesPage)
                        const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 30.0, horizontal: 16.0),
                              child: Text('No replies yet. Be the first to share your thoughts!'),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final ForumReply reply = replies[index];
                              return _buildReplyItem(context, reply, reply.userId == currentUserId);
                            },
                            childCount: replies.length,
                          ),
                        ),
                      if (detailsState.isLoadingNextRepliesPage)
                        const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                print('Error in ForumThreadScreen UI for thread ${widget.threadId}: $error\n$stack');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Failed to load thread details: ${error.toString()}', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.read(forumThreadDetailsProvider(widget.threadId).notifier).refresh(),
                          child: const Text('Try Again'),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildReplyInputArea(context),
        ],
      ),
    );
  }

  /// Builds the content view for the main forum thread.
  Widget _buildThreadContentView(BuildContext context, ForumThread thread) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              thread.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Started by: ...${thread.userId?.substring(thread.userId!.length - 6) ?? "N/A"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'On: ${DateFormat.yMMMMEEEEd().add_jm().format(thread.createdAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (thread.createdAt.isAtSameMomentAs(thread.updatedAt) == false) // Show updated only if different
                 Padding(
                   padding: const EdgeInsets.only(top: 2.0),
                   child: Text(
                     'Last activity: ${DateFormat.yMd().add_jm().format(thread.updatedAt.toLocal())}',
                     style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                   ),
                 ),
            if (thread.content != null && thread.content!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(thread.content!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16)),
            ],
            const Divider(height: 32, thickness: 1.5),
          ],
        ),
      ),
    );
  }

  /// Builds a single reply item widget.
  Widget _buildReplyItem(BuildContext context, ForumReply reply, bool isCurrentUserReply) {
    final ThemeData theme = Theme.of(context);
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reply.message, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '...${reply.userId?.substring(reply.userId!.length - 6) ?? "N/A"}',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                ),
                Text(
                  DateFormat.yMd().add_jm().format(reply.createdAt.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
            // TODO: Add UI for nested replies if parentReplyId is used.
          ],
        ),
      ),
    );
  }

  /// Builds the input area for typing and sending new replies.
  Widget _buildReplyInputArea(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Accessing provider's isPostingReply for more robust disabling if needed,
    // but local _isAttemptingPost provides immediate feedback.
    final bool providerIsPosting = ref.watch(forumThreadDetailsProvider(widget.threadId)).value?.isPostingReply ?? false;
    final bool actualIsSending = _isAttemptingPost || providerIsPosting;

    return Material(
      elevation: 8.0,
      color: theme.cardColor, // Or theme.bottomAppBarColor
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 8.0,
          top: 12.0,
          bottom: MediaQuery.of(context).padding.bottom + 12.0 // Handles notch
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end, // Align items to bottom for multi-line TextField
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                decoration: InputDecoration(
                  hintText: 'Write a reply...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.0),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.0),
                    borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                  ),
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => actualIsSending ? null : _postReply(),
                minLines: 1,
                maxLines: 5,
                enabled: !actualIsSending,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: actualIsSending
                  ? SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.primaryColor))
                  : Icon(Icons.send_rounded, color: theme.primaryColor),
              onPressed: actualIsSending || _replyController.text.trim().isEmpty ? null : _postReply,
              iconSize: 28,
              tooltip: 'Send Reply',
            ),
          ],
        ),
      ),
    );
  }
}
