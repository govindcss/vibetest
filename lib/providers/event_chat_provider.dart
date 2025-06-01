import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../repositories/event_repository.dart';
// Assuming eventRepositoryProvider is defined in event_providers.dart or similar
import 'event_providers.dart';


/// A stream provider that provides a list of [ChatMessage]s for a given event.
///
/// This provider is a family that takes an `eventId` (String) as an argument.
/// It watches the [eventRepositoryProvider] to get an instance of [EventRepository]
/// and then calls [EventRepository.getChatMessagesStream] to fetch the real-time
/// stream of chat messages.
///
/// UI widgets can use this provider to listen to live updates of chat messages
/// for a specific event.
final eventChatProvider = StreamProvider.family<List<ChatMessage>, String>((ref, eventId) {
  // Obtain the EventRepository instance from its provider.
  final eventRepository = ref.watch(eventRepositoryProvider);
  // Return the stream of chat messages for the given eventId.
  // The StreamProvider will handle the stream's lifecycle, including
  // listening for new data, errors, and closing the stream when the provider is disposed.
  return eventRepository.getChatMessagesStream(eventId);
});

// Note on sending messages:
// Sending chat messages is typically an action performed by the user.
// This can be handled by calling the `EventRepository.sendChatMessage` method directly
// from a UI widget (e.g., using `ref.read(eventRepositoryProvider).sendChatMessage(...)`).
// If more complex state management around sending messages is needed (e.g., tracking
// sending status, optimistic updates), an `AsyncNotifier` could be introduced for
// managing the chat input and message sending process. However, for simple cases,
// direct repository calls for actions like sending messages are often sufficient,
// especially when the stream automatically reflects the new message.
