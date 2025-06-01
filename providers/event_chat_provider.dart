import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../repositories/event_repository.dart'; // Assuming eventRepositoryProvider is here or accessible

// This provider should ideally be in a shared location if not already,
// like 'event_providers.dart' or a general 'repository_providers.dart'.
// For now, assuming it's accessible or defined in 'event_providers.dart'.
// final eventRepositoryProvider = Provider<EventRepository>((ref) => EventRepository());
// If it's in event_providers.dart, ensure this file imports it.
import 'event_providers.dart'; // Example if eventRepositoryProvider is in event_providers.dart


final eventChatProvider = StreamProvider.family<List<ChatMessage>, String>((ref, eventId) {
  final eventRepository = ref.watch(eventRepositoryProvider);
  return eventRepository.getChatMessagesStream(eventId);
});
