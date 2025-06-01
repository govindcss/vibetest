import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';
import '../models/event_user.dart';
import '../models/chat_message.dart';
import '../models/forum_thread.dart';
import '../models/forum_reply.dart';

/// A repository for handling event-related data operations with Supabase.
///
/// This class encapsulates all the logic for fetching, creating, updating,
/// and deleting event data, as well as related entities like attendees (event users),
/// chat messages, forum threads, and forum replies.
class EventRepository {
  final SupabaseClient _client;

  /// Constructs an [EventRepository].
  ///
  /// An optional [SupabaseClient] can be provided for testing or specific configurations,
  /// otherwise, it defaults to `Supabase.instance.client`.
  EventRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  /// Fetches a paginated list of events.
  ///
  /// Events are ordered by their [Event.startTime].
  /// RLS policies are expected to filter events based on user authentication status
  /// (e.g., public events, events user is a member of, or events user created).
  ///
  /// - [page]: The page number to fetch (0-indexed).
  /// - [pageSize]: The number of events to fetch per page.
  /// Returns a list of [Event] objects.
  /// Throws an [Exception] if fetching fails.
  Future<List<Event>> fetchEvents({int page = 0, int pageSize = 20}) async {
    try {
      final response = await _client
          .from('events')
          .select() // RLS handles visibility
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
      // Rethrowing allows the caller (e.g., Riverpod provider) to handle the error state.
      rethrow;
    }
  }

  /// Fetches details for a single event by its ID.
  ///
  /// - [eventId]: The ID of the event to fetch.
  /// Returns the [Event] object.
  /// Throws an [Exception] if the event is not found or fetching fails.
  Future<Event> fetchEventDetails(String eventId) async {
    try {
      final response = await _client
          .from('events')
          .select()
          .eq('id', eventId)
          .single() // Expects a single row; errors if 0 or >1 rows
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

  /// Fetches the list of users (attendees/members) for a given event.
  ///
  /// - [eventId]: The ID of the event for which to fetch attendees.
  /// Returns a list of [EventUser] objects.
  /// Throws an [Exception] if fetching fails.
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

  /// Allows the current authenticated user to join an event.
  ///
  /// Inserts a record into the `event_users` table.
  /// The user's role defaults to 'attendee' as per the database schema.
  /// RLS policies on `event_users` table must allow this insertion.
  ///
  /// - [eventId]: The ID of the event to join.
  /// Throws an [Exception] if the user is not authenticated or if the operation fails.
  Future<void> joinEvent(String eventId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated. Cannot join event.');
    }
    try {
      final response = await _client
          .from('event_users')
          .insert({
            'event_id': eventId,
            'user_id': currentUser.id,
            // 'role' defaults to 'attendee' in DB
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

  /// Allows the current authenticated user to leave an event.
  ///
  /// Deletes the user's record from the `event_users` table for the specified event.
  /// RLS policies on `event_users` table must allow this deletion.
  ///
  /// - [eventId]: The ID of the event to leave.
  /// Throws an [Exception] if the user is not authenticated or if the operation fails.
  Future<void> leaveEvent(String eventId) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated. Cannot leave event.');
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

  /// Allows an authorized user (event creator/host) to update an event's privacy status.
  ///
  /// RLS policies on the `events` table must authorize this update.
  ///
  /// - [eventId]: The ID of the event to update.
  /// - [isPublic]: The new privacy status (true for public, false for private).
  /// Throws an [Exception] if the operation fails.
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

  // --- Event Chat Methods ---

  /// Sends a chat message to an event's chat.
  ///
  /// The message is sent by the current authenticated user.
  /// RLS policies on `event_chats` table must allow this insertion.
  ///
  /// - [eventId]: The ID of the event where the message is sent.
  /// - [message]: The content of the message. Cannot be empty.
  /// Throws an [Exception] if the user is not authenticated, the message is empty, or sending fails.
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
            // 'created_at' is set by DB default
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

  /// Retrieves a real-time stream of chat messages for a specific event.
  ///
  /// Messages are ordered by their creation time (ascending).
  /// RLS policies on `event_chats` table must allow the user to select these messages.
  ///
  /// - [eventId]: The ID of the event whose chat messages are to be streamed.
  /// Returns a stream of `List<ChatMessage>`.
  /// Emits an error on the stream if fetching or transformation fails.
  Stream<List<ChatMessage>> getChatMessagesStream(String eventId) {
    try {
      // Uses Supabase real-time filtering on the 'event_id' column.
      return _client
          .from('event_chats:event_id=eq.$eventId')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true)
          .map((listOfMaps) {
            // This map function is applied to each new snapshot from the stream.
            if (listOfMaps.isEmpty) {
              return [];
            }
            return listOfMaps.map((map) => ChatMessage.fromJson(map as Map<String, dynamic>)).toList();
          })
          .handleError((error) {
            print('Error in chat messages stream for event $eventId: $error');
            // This error will be caught by StreamProvider and exposed in AsyncValue.error.
            throw Exception('Error in chat stream: $error');
          });
    } catch (e) {
      print('Exception setting up getChatMessagesStream for $eventId: $e');
      // Return a stream that emits an error immediately if setup fails.
      return Stream.error(Exception('Failed to set up chat stream: $e'));
    }
  }

  // --- Event Forum Methods ---

  /// Fetches a paginated list of forum threads for a specific event.
  ///
  /// Threads are ordered by their last update time (`updated_at` descending).
  /// RLS policies on `event_forum_threads` must allow access.
  ///
  /// - [eventId]: The ID of the event for which to fetch threads.
  /// - [page]: The page number (0-indexed).
  /// - [pageSize]: The number of threads per page.
  /// Returns a list of [ForumThread] objects.
  /// Throws an [Exception] if fetching fails.
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
          .order('updated_at', ascending: false)
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

  /// Fetches details for a single forum thread by its ID.
  ///
  /// - [threadId]: The ID of the forum thread to fetch.
  /// Returns the [ForumThread] object.
  /// Throws an [Exception] if the thread is not found or fetching fails.
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

  /// Creates a new forum thread for an event.
  ///
  /// The thread is created by the current authenticated user.
  /// RLS policies on `event_forum_threads` must allow this insertion.
  ///
  /// - [eventId]: The ID of the event to associate the thread with.
  /// - [title]: The title of the thread. Cannot be empty.
  /// - [content]: Optional initial content for the thread.
  /// Returns the created [ForumThread] object.
  /// Throws an [Exception] if the user is not authenticated, title is empty, or creation fails.
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
      final response = await _client
          .from('event_forum_threads')
          .insert({
            'event_id': eventId,
            'user_id': currentUser.id,
            'title': title.trim(),
            'content': content?.trim().isNotEmpty == true ? content!.trim() : null, // Store null if content is empty string
            // 'created_at' and 'updated_at' are set by DB defaults
          })
          .select() // Fetch the inserted row to get all fields, including auto-generated ones
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

  /// Fetches paginated replies for a specific forum thread.
  ///
  /// Replies are ordered by their creation time (`created_at` ascending).
  /// RLS policies on `event_forum_replies` must allow access.
  ///
  /// - [threadId]: The ID of the forum thread for which to fetch replies.
  /// - [page]: The page number (0-indexed).
  /// - [pageSize]: The number of replies per page.
  /// Returns a list of [ForumReply] objects.
  /// Throws an [Exception] if fetching fails.
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
          .order('created_at', ascending: true)
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

  /// Creates a new reply to a forum thread.
  ///
  /// The reply is posted by the current authenticated user.
  /// RLS policies on `event_forum_replies` must allow this insertion.
  /// Posting a reply also updates the `updated_at` timestamp of the parent thread via a database trigger.
  ///
  /// - [threadId]: The ID of the thread to reply to.
  /// - [message]: The content of the reply. Cannot be empty.
  /// - [parentReplyId]: Optional ID of a parent reply if this is a nested reply.
  /// Returns the created [ForumReply] object.
  /// Throws an [Exception] if the user is not authenticated, message is empty, or creation fails.
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
            // 'created_at' is set by DB default
          })
          .select() // Fetch the inserted row
          .single()   // Expect a single row back
          .execute();

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
