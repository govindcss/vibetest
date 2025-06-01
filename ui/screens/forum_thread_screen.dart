import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:supabase_flutter/supabase_flutter.dart'; // For currentUserId

import '../../models/forum_thread.dart';
import '../../models/forum_reply.dart';
import '../../providers/forum_providers.dart';

class ForumThreadScreen extends ConsumerStatefulWidget {
  final int threadId;

  const ForumThreadScreen({Key? key, required this.threadId}) : super(key: key);

  @override
  ConsumerState<ForumThreadScreen> createState() => _ForumThreadScreenState();
}

class _ForumThreadScreenState extends ConsumerState<ForumThreadScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _replyController = TextEditingController();
  bool _isPostingReply = false; // Local state for reply input disabling

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_isBottom) {
      final notifier = ref.read(forumThreadDetailsProvider(widget.threadId).notifier);
      final currentDetailsState = ref.read(forumThreadDetailsProvider(widget.threadId)).value;
      if (currentDetailsState != null && !currentDetailsState.isLoadingNextRepliesPage && !currentDetailsState.hasReachedMaxReplies) {
        notifier.fetchNextRepliesPage();
      }
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  Future<void> _postReply() async {
    if (_replyController.text.trim().isEmpty) return;

    setState(() { _isPostingReply = true; });

    try {
      await ref.read(forumThreadDetailsProvider(widget.threadId).notifier).addReply(_replyController.text.trim());
      _replyController.clear();
      // Scroll to bottom might be good here if new replies are added at the end and list doesn't auto-rebuild & scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
             _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
        }
      });
    } catch (e) {
      // Error is handled by the provider and potentially shown via SnackBar by listener
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting reply: ${e.toString()}')),
        );
      }
    } finally {
       if (mounted) {
        setState(() { _isPostingReply = false; });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadDetailsAsyncValue = ref.watch(forumThreadDetailsProvider(widget.threadId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    ref.listen<AsyncValue<ForumThreadDetailsState>>(forumThreadDetailsProvider(widget.threadId), (_, next) {
      if (next.value?.errorMessage != null && next.value!.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.value!.errorMessage!)),
        );
      }
      // Update local _isPostingReply if the provider's state changes (e.g. error during post)
      if (mounted && (next.value?.isPostingReply ?? false) != _isPostingReply) {
        setState(() {
          _isPostingReply = next.value?.isPostingReply ?? false;
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(threadDetailsAsyncValue.value?.threadDetails?.title ?? 'Thread Details'),
         actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(thread.title, style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 8),
                              Text('Started by: User ${thread.userId?.substring(0,6) ?? "N/A"}... on ${DateFormat.yMd().add_jm().format(thread.createdAt.toLocal())}'),
                              if (thread.content != null && thread.content!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(thread.content!, style: Theme.of(context).textTheme.bodyLarge),
                              ],
                              const Divider(height: 32, thickness: 1),
                              Text('Replies (${replies.length})', style: Theme.of(context).textTheme.titleLarge),
                            ],
                          ),
                        ),
                      ),
                      if (replies.isEmpty)
                        const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: Text('No replies yet. Be the first to reply!'),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final ForumReply reply = replies[index];
                              final bool isCurrentUserReply = reply.userId == currentUserId;
                              return _buildReplyItem(reply, isCurrentUserReply, context);
                            },
                            childCount: replies.length,
                          ),
                        ),
                      if (detailsState.isLoadingNextRepliesPage)
                        const SliverToBoxAdapter(
                          child: Center(child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          )),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                print('Error in ForumThreadScreen: $error\n$stack');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Failed to load thread: ${error.toString()}'),
                      ElevatedButton(
                        onPressed: () => ref.read(forumThreadDetailsProvider(widget.threadId).notifier).refresh(),
                        child: const Text('Try Again'),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
          _buildReplyInputArea(),
        ],
      ),
    );
  }

  Widget _buildReplyItem(ForumReply reply, bool isCurrentUserReply, BuildContext context) {
    // Basic styling, can be enhanced
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isCurrentUserReply ? Colors.blue[50] : Colors.grey[100],
      child: ListTile(
        title: Text(reply.message),
        subtitle: Text('User: ${reply.userId?.substring(0,6) ?? "N/A"} - ${DateFormat.yMd().add_jm().format(reply.createdAt.toLocal())}'),
        // TODO: Add support for parentReplyId display or nested view if desired
      ),
    );
  }

  Widget _buildReplyInputArea() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 1,
            color: Colors.grey.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              decoration: const InputDecoration(
                hintText: 'Write a reply...',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_)=> _isPostingReply ? null : _postReply(),
              minLines: 1,
              maxLines: 4,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send_rounded),
            onPressed: _isPostingReply || _replyController.text.trim().isEmpty ? null : _postReply,
            color: Theme.of(context).primaryColor,
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _replyController.dispose();
    super.dispose();
  }
}
