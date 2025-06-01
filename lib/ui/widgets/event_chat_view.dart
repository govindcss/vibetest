import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For currentUserId
import 'package:intl/intl.dart'; // For formatting dates

import '../../models/chat_message.dart';
import '../../providers/event_chat_provider.dart';
import '../../providers/event_providers.dart'; // For eventRepositoryProvider

/// A widget that displays real-time chat messages for a given event
/// and allows the current user to send new messages.
///
/// It takes an `eventId` and uses [eventChatProvider] to stream messages
/// and [eventRepositoryProvider] to send messages.
class EventChatView extends ConsumerStatefulWidget {
  /// The unique identifier of the event for which to display chat messages.
  final String eventId;

  /// Constructs an [EventChatView].
  /// Requires an [eventId].
  const EventChatView({Key? key, required this.eventId}) : super(key: key);

  @override
  ConsumerState<EventChatView> createState() => _EventChatViewState();
}

class _EventChatViewState extends ConsumerState<EventChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // It's good practice to scroll to bottom after the first frame renders if messages are already present.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls the message list to the bottom.
  /// Can optionally jump directly or animate.
  void _scrollToBottom({bool jump = false}) {
    if (_scrollController.hasClients) {
      final position = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(position);
      } else {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  /// Sends the message typed by the user.
  ///
  /// Clears the input field on success and shows a SnackBar on failure.
  /// Disables the send button while the message is being sent.
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) {
      return;
    }
    // Set state to indicate sending and disable button
    setState(() {
      _isSending = true;
    });

    try {
      await ref.read(eventRepositoryProvider).sendChatMessage(
            eventId: widget.eventId,
            message: _messageController.text.trim(),
          );
      _messageController.clear();
      // Wait for the stream to update and then scroll.
      // A short delay can help ensure the new message is rendered before scrolling.
      Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        // Re-enable button
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatAsyncValue = ref.watch(eventChatProvider(widget.eventId));
    final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Listen to stream updates to scroll to bottom when new messages arrive.
    ref.listen(eventChatProvider(widget.eventId), (previous, next) {
      if (previous?.value?.length != next.value?.length && (next.value?.isNotEmpty ?? false)) {
         WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Column(
      children: [
        Expanded(
          child: chatAsyncValue.when(
            data: (messages) {
              if (messages.isEmpty) {
                return const Center(child: Text('No messages yet. Be the first!'));
              }
              // Initial scroll after list is built.
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true));
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8.0),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final ChatMessage message = messages[index];
                  final bool isCurrentUser = message.userId == currentUserId;
                  return _buildMessageItem(context, message, isCurrentUser);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              print('Error in EventChatView stream UI: $error\n$stack');
              return Center(
                child: Text('Error loading messages: ${error.toString()}'),
              );
            },
          ),
        ),
        _buildMessageInputArea(context),
      ],
    );
  }

  /// Builds a single message item widget.
  /// Differentiates styling for messages sent by the current user.
  Widget _buildMessageItem(BuildContext context, ChatMessage message, bool isCurrentUser) {
    final ThemeData theme = Theme.of(context);
    final alignment = isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isCurrentUser ? theme.primaryColor.withOpacity(0.8) : theme.colorScheme.surfaceVariant;
    final textColor = isCurrentUser ? Colors.white : theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          // Optional: Display user name/identifier if not current user
          // if (!isCurrentUser && message.userId != null)
          //   Padding(
          //     padding: const EdgeInsets.only(bottom: 2.0, left: 8.0, right: 8.0),
          //     child: Text(
          //       'User: ...${message.userId!.substring(message.userId!.length - 6)}', // Example: show last 6 chars
          //       style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          //     ),
          //   ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18.0),
                topRight: const Radius.circular(18.0),
                bottomLeft: isCurrentUser ? const Radius.circular(18.0) : const Radius.circular(4.0),
                bottomRight: isCurrentUser ? const Radius.circular(4.0) : const Radius.circular(18.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.message,
                  style: TextStyle(color: textColor, fontSize: 15.0),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.jm().format(message.createdAt.toLocal()), // Display time
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isCurrentUser ? Colors.white.withOpacity(0.8) : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the input area for typing and sending chat messages.
  Widget _buildMessageInputArea(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      elevation: 4.0, // Add elevation for a visual lift
      color: theme.cardColor,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12.0,
          right: 8.0,
          top: 8.0,
          bottom: MediaQuery.of(context).padding.bottom + 8.0 // Adjust for keyboard/notch
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor, // Or a slightly different shade
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                minLines: 1,
                maxLines: 5, // Allow multi-line messages
                enabled: !_isSending, // Disable when sending
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _isSending
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor))
                  : Icon(Icons.send_rounded, color: theme.primaryColor),
              onPressed: _isSending || _messageController.text.trim().isEmpty ? null : _sendMessage,
              tooltip: 'Send Message',
            ),
          ],
        ),
      ),
    );
  }
}
