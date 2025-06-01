import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';
import '../models/event_user.dart';
import '../models/chat_message.dart';
import '../models/forum_thread.dart'; // Added ForumThread model
import '../models/forum_reply.dart';   // Added ForumReply model

class EventRepository {
  final SupabaseClient _client;

  EventRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  // ... existing event, event_user, chat methods ...

  Future<List<Event>> fetchEvents({int page = 0, int pageSize = 20}) async {
    try {
      final response = await _client
          .from('events')
          .select()
          .order('start_time', ascending: true)
          .range(page * pageSize, (page + 1) * pageSize - 1)
          .execute();

      if (response.error != null) {
        print('Error fetching events: ${response.error!.message}');
        throw Exception('Failed to fetch events: ${response.error!.message}');
      }

      final data = response.data as List<dynamic>?;
      if (data == null) {
        return [];
      }

      return data.map((json) => Event.fromJson(json as Map<String, dynamic>)).toList();

    } catch (e) {
      print('Exception in fetchEvents: $e');
      rethrow;
    }
  }

  Future<Event> fetchEventDetails(String eventId) async {
    try {
      final response = await _client
          .from('events')
          .select()
          .eq('id', eventId)
          .single()
          .execute();

      if (response.error != null) {
        print('Error fetching event details for $eventId: ${response.error!.message}');
        throw Exception('Failed to fetch event details: ${response.error!.message}');
      }
      if (response.data == null) {
        print('No data found for event details $eventId');
        throw Exception('Event not found.');
      }
      return Event.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      print('Exception in fetchEventDetails for $eventId: $e');
      rethrow;
    }
  }

  Future<List<EventUser>> fetchEventAttendees(String eventId) async {
    try {
      final response = await _client
          .from('event_users')
          .select()
          .eq('event_id', eventId)
          .execute();

      if (response.error != null) {
        print('Error fetching event attendees for $eventId: ${response.error!.message}');
        throw Exception('Failed to fetch event attendees: ${response.error!.message}');
      }

      final data = response.data as List<dynamic>?;
      if (data == null) {
        return [];
      }
      return data.map((json) => EventUser.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Exception in fetchEventAttendees for $eventId: $e');
      rethrow;
    }
  }

  Future<void> joinEvent(String eventId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated.');
    }
    try {
      final response = await _client
          .from('event_users')
          .insert({
            'event_id': eventId,
            'user_id': currentUser.id,
          })
          .execute();

      if (response.error != null) {
        print('Error joining event $eventId: ${response.error!.message}');
        throw Exception('Failed to join event: ${response.error!.message}');
      }
    } catch (e) {
      print('Exception in joinEvent for $eventId: $e');
      rethrow;
    }
  }

  Future<void> leaveEvent(String eventId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated.');
    }
    try {
      final response = await _client
          .from('event_users')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', currentUser.id)
          .execute();

      if (response.error != null) {
        print('Error leaving event $eventId: ${response.error!.message}');
        throw Exception('Failed to leave event: ${response.error!.message}');
      }
    } catch (e) {
      print('Exception in leaveEvent for $eventId: $e');
      rethrow;
    }
  }

  Future<void> updateEventPrivacy(String eventId, bool isPublic) async {
    try {
      final response = await _client
          .from('events')
          .update({'is_public': isPublic})
          .eq('id', eventId)
          .execute();

      if (response.error != null) {
        print('Error updating event privacy for $eventId: ${response.error!.message}');
        throw Exception('Failed to update event privacy: ${response.error!.message}');
      }
    } catch (e) {
      print('Exception in updateEventPrivacy for $eventId: $e');
      rethrow;
    }
  }

  Future<void> sendChatMessage({required String eventId, required String message}) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated to send message.');
    }
    if (message.trim().isEmpty) {
      throw Exception('Message cannot be empty.');
    }

    try {
      final response = await _client
          .from('event_chats')
          .insert({
            'event_id': eventId,
            'user_id': currentUser.id,
            'message': message.trim(),
          })
          .execute();

      if (response.error != null) {
        print('Error sending chat message for event $eventId: ${response.error!.message}');
        throw Exception('Failed to send message: ${response.error!.message}');
      }
    } catch (e) {
      print('Exception in sendChatMessage for $eventId: $e');
      rethrow;
    }
  }

  Stream<List<ChatMessage>> getChatMessagesStream(String eventId) {
    try {
      return _client
          .from('event_chats:event_id=eq.$eventId')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true)
          .map((listOfMaps) {
            if (listOfMaps.isEmpty) {
              return [];
            }
            return listOfMaps.map((map) => ChatMessage.fromJson(map as Map<String, dynamic>)).toList();
          })
          .handleError((error) {
            print('Error in chat messages stream for event $eventId: $error');
            throw Exception('Error in chat stream: $error');
          });
    } catch (e) {
      print('Exception setting up getChatMessagesStream for $eventId: $e');
      return Stream.error(Exception('Failed to set up chat stream: $e'));
    }
  }

  // --- Event Forum Methods ---

  Future<List<ForumThread>> fetchForumThreads({
    required String eventId,
    int page = 0,
    int pageSize = 15,
  }) async {
    try {
      final response = await _client
          .from('event_forum_threads')
          .select()
          .eq('event_id', eventId)
          .order('updated_at', ascending: false) // Typically newest updated threads first
          .range(page * pageSize, (page + 1) * pageSize - 1)
          .execute();

      if (response.error != null) {
        print('Error fetching forum threads for event $eventId: ${response.error!.message}');
        throw Exception('Failed to fetch forum threads: ${response.error!.message}');
      }
      final data = response.data as List<dynamic>?;
      if (data == null) return [];
      return data.map((json) => ForumThread.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Exception in fetchForumThreads for $eventId: $e');
      rethrow;
    }
  }

  Future<ForumThread> fetchForumThreadDetails({required int threadId}) async {
    try {
      final response = await _client
          .from('event_forum_threads')
          .select()
          .eq('id', threadId)
          .single()
          .execute();

      if (response.error != null) {
        print('Error fetching forum thread details for thread $threadId: ${response.error!.message}');
        throw Exception('Failed to fetch thread details: ${response.error!.message}');
      }
      if (response.data == null) {
         print('No data found for thread details $threadId');
        throw Exception('Thread not found.');
      }
      return ForumThread.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      print('Exception in fetchForumThreadDetails for $threadId: $e');
      rethrow;
    }
  }

  Future<ForumThread> createForumThread({
    required String eventId,
    required String title,
    String? content,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated to create a thread.');
    }
    if (title.trim().isEmpty) {
      throw Exception('Title cannot be empty.');
    }

    try {
      // Insert and then select to get the full object with defaults (like created_at, id)
      // Supabase insert doesn't return the full object by default in the same way as select.
      // .select() after insert is a common pattern.
      final response = await _client
          .from('event_forum_threads')
          .insert({
            'event_id': eventId,
            'user_id': currentUser.id,
            'title': title.trim(),
            'content': content?.trim(),
            // 'created_at' and 'updated_at' will be set by DB defaults
          })
          .select() // Fetch the inserted row
          .single()   // Expect a single row back
          .execute();

      if (response.error != null) {
        print('Error creating forum thread for event $eventId: ${response.error!.message}');
        throw Exception('Failed to create forum thread: ${response.error!.message}');
      }
       if (response.data == null) {
        print('No data returned after creating forum thread for event $eventId');
        throw Exception('Failed to retrieve created forum thread.');
      }
      return ForumThread.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      print('Exception in createForumThread for $eventId: $e');
      rethrow;
    }
  }

  Future<List<ForumReply>> fetchForumReplies({
    required int threadId,
    int page = 0,
    int pageSize = 15,
  }) async {
    try {
      final response = await _client
          .from('event_forum_replies')
          .select()
          .eq('thread_id', threadId)
          .order('created_at', ascending: true) // Oldest replies first for reading order
          .range(page * pageSize, (page + 1) * pageSize - 1)
          .execute();

      if (response.error != null) {
        print('Error fetching forum replies for thread $threadId: ${response.error!.message}');
        throw Exception('Failed to fetch forum replies: ${response.error!.message}');
      }
      final data = response.data as List<dynamic>?;
      if (data == null) return [];
      return data.map((json) => ForumReply.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Exception in fetchForumReplies for $threadId: $e');
      rethrow;
    }
  }

  Future<ForumReply> createForumReply({
    required int threadId,
    required String message,
    int? parentReplyId,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated to create a reply.');
    }
    if (message.trim().isEmpty) {
      throw Exception('Message cannot be empty.');
    }

    try {
      final response = await _client
          .from('event_forum_replies')
          .insert({
            'thread_id': threadId,
            'user_id': currentUser.id,
            'message': message.trim(),
            'parent_reply_id': parentReplyId,
            // 'created_at' will be set by DB default
          })
          .select()
          .single()
          .execute();

      // This will also update the parent thread's 'updated_at' via the trigger in SQL.

      if (response.error != null) {
        print('Error creating forum reply for thread $threadId: ${response.error!.message}');
        throw Exception('Failed to create forum reply: ${response.error!.message}');
      }
      if (response.data == null) {
        print('No data returned after creating forum reply for thread $threadId');
        throw Exception('Failed to retrieve created forum reply.');
      }
      return ForumReply.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      print('Exception in createForumReply for $threadId: $e');
      rethrow;
    }
  }
}
