import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For currentUserId
import 'package:intl/intl.dart'; // For formatting dates

import '../../models/chat_message.dart';
import '../../providers/event_chat_provider.dart';
import '../../providers/event_providers.dart'; // For eventRepositoryProvider

class EventChatView extends ConsumerStatefulWidget {
  final String eventId;

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
    // Optional: Scroll to bottom when new messages arrive and list builds
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _isSending = true;
    });

    try {
      await ref.read(eventRepositoryProvider).sendChatMessage(
            eventId: widget.eventId,
            message: _messageController.text.trim(),
          );
      _messageController.clear();
      _scrollToBottom(); // Scroll after sending a new message
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatAsyncValue = ref.watch(eventChatProvider(widget.eventId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Automatically scroll to bottom when new messages arrive
    ref.listen(eventChatProvider(widget.eventId), (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Column(
      children: [
        Expanded(
          child: chatAsyncValue.when(
            data: (messages) {
              if (messages.isEmpty) {
                return const Center(child: Text('No messages yet. Be the first!'));
              }
              // Give a bit of delay for list to build before scrolling
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8.0),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final bool isCurrentUser = message.userId == currentUserId;
                  return _buildMessageItem(message, isCurrentUser, context);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              print('Error in EventChatView stream: $error\n$stack');
              return Center(
                child: Text('Error loading messages: ${error.toString()}'),
              );
            },
          ),
        ),
        _buildMessageInputArea(),
      ],
    );
  }

  Widget _buildMessageItem(ChatMessage message, bool isCurrentUser, BuildContext context) {
    final alignment = isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isCurrentUser ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey[200];
    final textColor = isCurrentUser ? Theme.of(context).primaryColorDark : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          // Optional: Display user ID or name
          // if (!isCurrentUser) Text(message.userId.substring(0, 6), style: Theme.of(context).textTheme.caption),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.message,
                  style: TextStyle(color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat.jm().format(message.createdAt.toLocal()), // Display time
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInputArea() {
    return Container(
      padding: const EdgeInsets.all(8.0),
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
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8.0)
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              minLines: 1,
              maxLines: 5,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _isSending || _messageController.text.trim().isEmpty ? null : _sendMessage,
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}
