import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forum_thread.dart';
import '../models/forum_reply.dart';
import '../repositories/event_repository.dart';
// Assuming eventRepositoryProvider is defined in event_providers.dart or similar
import 'event_providers.dart';


// --- Forum Threads List (per Event) ---

/// Represents the state for a paginated list of forum threads for a specific event.
class ForumThreadsState {
  /// The current list of fetched forum threads.
  final List<ForumThread> threads;

  /// Indicates if the next page of threads is currently being loaded.
  final bool isLoadingNextPage;

  /// Indicates if all available threads for the event have been fetched.
  final bool hasReachedMax;

  /// The current page number of threads that has been fetched (0-indexed).
  final int currentPage;

  /// An optional error message if an error occurred during fetching threads.
  final String? errorMessage;

  /// Constructs a [ForumThreadsState].
  ForumThreadsState({
    this.threads = const [],
    this.isLoadingNextPage = false,
    this.hasReachedMax = false,
    this.currentPage = 0,
    this.errorMessage,
  });

  /// Creates a copy of this [ForumThreadsState] instance with specified fields updated.
  ForumThreadsState copyWith({
    List<ForumThread>? threads,
    bool? isLoadingNextPage,
    bool? hasReachedMax,
    int? currentPage,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ForumThreadsState(
      threads: threads ?? this.threads,
      isLoadingNextPage: isLoadingNextPage ?? this.isLoadingNextPage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      currentPage: currentPage ?? this.currentPage,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

/// Manages the state of a paginated list of forum threads for a specific event.
///
/// This notifier is a [FamilyAsyncNotifier], taking an `eventId` (String) as an argument.
/// It handles fetching initial threads and subsequent pages, and allows refreshing the list.
/// It also provides a method to optimistically add a newly created thread.
class ForumThreadsNotifier extends FamilyAsyncNotifier<ForumThreadsState, String> {
  /// The number of forum threads to fetch per page.
  static const int _pageSize = 15;

  /// The ID of the event for which threads are being managed. Accessed via `arg`.
  String get _eventId => arg;

  /// Helper method to fetch a specific page of forum threads.
  Future<List<ForumThread>> _fetchPage(int page) async {
    final repository = ref.read(eventRepositoryProvider);
    // Errors from repository.fetchForumThreads will propagate and be handled by AsyncNotifier
    return await repository.fetchForumThreads(
      eventId: _eventId,
      page: page,
      pageSize: _pageSize,
    );
  }

  /// Fetches the initial page of forum threads when the provider is first built.
  @override
  Future<ForumThreadsState> build(String eventId) async {
    final initialThreads = await _fetchPage(0);
    return ForumThreadsState(
      threads: initialThreads,
      currentPage: 0,
      hasReachedMax: initialThreads.length < _pageSize,
    );
  }

  /// Fetches the next page of forum threads.
  ///
  /// Updates the state by appending new threads to the existing list.
  /// Manages loading and error states for this specific operation.
  Future<void> fetchNextPage() async {
    final previousStateValue = state.value;
    if (previousStateValue == null || previousStateValue.isLoadingNextPage || previousStateValue.hasReachedMax) {
      return;
    }
    state = AsyncData(previousStateValue.copyWith(isLoadingNextPage: true, clearErrorMessage: true));
    try {
      final nextPage = previousStateValue.currentPage + 1;
      final newThreads = await _fetchPage(nextPage);
      state = AsyncData(previousStateValue.copyWith(
        threads: [...previousStateValue.threads, ...newThreads],
        currentPage: nextPage,
        isLoadingNextPage: false,
        hasReachedMax: newThreads.length < _pageSize,
      ));
    } catch (e) {
      state = AsyncData(previousStateValue.copyWith(isLoadingNextPage: false, errorMessage: e.toString()));
    }
  }

  /// Refreshes the list of forum threads by fetching the first page again.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final initialThreads = await _fetchPage(0);
      state = AsyncData(ForumThreadsState(
        threads: initialThreads,
        currentPage: 0,
        hasReachedMax: initialThreads.length < _pageSize,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Adds a newly created [ForumThread] to the beginning of the current list.
  ///
  /// This is an optimistic update to make the UI feel more responsive after thread creation.
  /// - [newThread]: The [ForumThread] object that was just created.
  void addCreatedThread(ForumThread newThread) {
    final previousStateValue = state.value;
    if (previousStateValue != null) {
      state = AsyncData(previousStateValue.copyWith(
        threads: [newThread, ...previousStateValue.threads],
        // Note: This doesn't change currentPage or hasReachedMax,
        // as it's an optimistic local update. A full refresh would get exact pagination.
      ));
    }
  }
}

/// Provider for [ForumThreadsNotifier].
///
/// This provider is a family that takes an `eventId` (String) as an argument.
/// It's used by UI widgets to display and manage the list of forum threads for an event.
final forumThreadsProvider = AsyncNotifierProviderFamily<ForumThreadsNotifier, ForumThreadsState, String>(() {
  return ForumThreadsNotifier();
});


// --- Forum Thread Details & Replies (per Thread) ---

/// Represents the state for a single forum thread's details and its replies.
///
/// Includes the [ForumThread] details, a paginated list of [ForumReply] objects,
/// loading states for replies and posting new replies, and error messages.
class ForumThreadDetailsState {
  /// The details of the forum thread. Null if not loaded or not found.
  final ForumThread? threadDetails;

  /// The current list of fetched replies for the thread.
  final List<ForumReply> replies;

  /// Indicates if the next page of replies is currently being loaded.
  final bool isLoadingNextRepliesPage;

  /// Indicates if all available replies for the thread have been fetched.
  final bool hasReachedMaxReplies;

  /// The current page number of replies that has been fetched (0-indexed).
  final int currentRepliesPage;

  /// Indicates if a new reply is currently being posted.
  final bool isPostingReply;

  /// An optional error message, e.g., if fetching details or posting a reply fails.
  final String? errorMessage;

  /// Constructs a [ForumThreadDetailsState].
  ForumThreadDetailsState({
    this.threadDetails,
    this.replies = const [],
    this.isLoadingNextRepliesPage = false,
    this.hasReachedMaxReplies = false,
    this.currentRepliesPage = 0,
    this.isPostingReply = false,
    this.errorMessage,
  });

  /// Creates a copy of this [ForumThreadDetailsState] instance with specified fields updated.
  ForumThreadDetailsState copyWith({
    ForumThread? threadDetails,
    List<ForumReply>? replies,
    bool? isLoadingNextRepliesPage,
    bool? hasReachedMaxReplies,
    int? currentRepliesPage,
    bool? isPostingReply,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ForumThreadDetailsState(
      threadDetails: threadDetails ?? this.threadDetails,
      replies: replies ?? this.replies,
      isLoadingNextRepliesPage: isLoadingNextRepliesPage ?? this.isLoadingNextRepliesPage,
      hasReachedMaxReplies: hasReachedMaxReplies ?? this.hasReachedMaxReplies,
      currentRepliesPage: currentRepliesPage ?? this.currentRepliesPage,
      isPostingReply: isPostingReply ?? this.isPostingReply,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

/// Manages the state for a single forum thread's details and its associated replies.
///
/// This notifier is a [FamilyAsyncNotifier], taking a `threadId` (int) as an argument.
/// It handles fetching the thread details, paginated replies, posting new replies,
/// and refreshing the data.
class ForumThreadDetailsNotifier extends FamilyAsyncNotifier<ForumThreadDetailsState, int> {
  /// The number of forum replies to fetch per page.
  static const int _repliesPageSize = 15;

  /// The ID of the forum thread being managed. Accessed via `arg`.
  int get _threadId => arg;

  /// Helper method to fetch initial data: thread details and first page of replies.
  Future<ForumThreadDetailsState> _fetchInitialData() async {
    final repository = ref.read(eventRepositoryProvider);
    // Fetch thread details and first page of replies concurrently.
    final results = await Future.wait([
      repository.fetchForumThreadDetails(threadId: _threadId),
      repository.fetchForumReplies(
        threadId: _threadId,
        page: 0,
        pageSize: _repliesPageSize,
      ),
    ]);

    final thread = results[0] as ForumThread;
    final initialReplies = results[1] as List<ForumReply>;

    return ForumThreadDetailsState(
      threadDetails: thread,
      replies: initialReplies,
      currentRepliesPage: 0,
      hasReachedMaxReplies: initialReplies.length < _repliesPageSize,
    );
  }

  /// Fetches initial thread data (details and first page of replies) when the provider is built.
  @override
  Future<ForumThreadDetailsState> build(int threadId) async {
    return _fetchInitialData();
  }

  /// Fetches the next page of replies for the current thread.
  Future<void> fetchNextRepliesPage() async {
    final previousStateValue = state.value;
    if (previousStateValue == null || previousStateValue.isLoadingNextRepliesPage || previousStateValue.hasReachedMaxReplies) {
      return;
    }
    state = AsyncData(previousStateValue.copyWith(isLoadingNextRepliesPage: true, clearErrorMessage: true));
    try {
      final nextPage = previousStateValue.currentRepliesPage + 1;
      final newReplies = await ref.read(eventRepositoryProvider).fetchForumReplies(
        threadId: _threadId,
        page: nextPage,
        pageSize: _repliesPageSize,
      );
      state = AsyncData(previousStateValue.copyWith(
        replies: [...previousStateValue.replies, ...newReplies],
        currentRepliesPage: nextPage,
        isLoadingNextRepliesPage: false,
        hasReachedMaxReplies: newReplies.length < _repliesPageSize,
      ));
    } catch (e) {
      state = AsyncData(previousStateValue.copyWith(isLoadingNextRepliesPage: false, errorMessage: e.toString()));
    }
  }

  /// Adds a new reply to the current forum thread.
  ///
  /// - [message]: The content of the reply.
  /// - [parentReplyId]: Optional ID of the parent reply for nested replies.
  ///
  /// After successfully posting the reply, it's added to the local state optimistically.
  /// It also invalidates the [forumThreadsProvider] for the parent event to ensure
  /// the thread list (ordered by `updated_at`) reflects this new activity.
  Future<void> addReply(String message, {int? parentReplyId}) async {
    final previousStateValue = state.value;
    if (previousStateValue == null || previousStateValue.isPostingReply || previousStateValue.threadDetails == null) {
      return;
    }

    state = AsyncData(previousStateValue.copyWith(isPostingReply: true, clearErrorMessage: true));
    try {
      final newReply = await ref.read(eventRepositoryProvider).createForumReply(
        threadId: _threadId,
        message: message,
        parentReplyId: parentReplyId,
      );

      // Optimistically add the new reply to the list.
      final updatedReplies = [...previousStateValue.replies, newReply];
      // The database trigger updates thread's updated_at. To reflect this in UI for thread lists:
      // 1. Refetch thread details to get updated 'updated_at' (or assume it's NOW())
      // 2. Invalidate the forumThreadsProvider for the event to trigger a refresh of the thread list.
      final eventId = previousStateValue.threadDetails!.eventId; // Must have threadDetails here
      ref.invalidate(forumThreadsProvider(eventId));


      state = AsyncData(previousStateValue.copyWith(
        replies: updatedReplies,
        isPostingReply: false,
        // Optionally update threadDetails.updatedAt if necessary, or rely on next refresh.
        // For simplicity, we assume the list invalidation is sufficient for now.
      ));
    } catch (e) {
      state = AsyncData(previousStateValue.copyWith(isPostingReply: false, errorMessage: e.toString()));
    }
  }

  /// Refreshes the thread details and its replies by fetching all data again.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await _fetchInitialData());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

/// Provider for [ForumThreadDetailsNotifier].
///
/// This provider is a family that takes a `threadId` (int) as an argument.
/// It's used by UI widgets to display and manage details and replies for a specific forum thread.
final forumThreadDetailsProvider = AsyncNotifierProviderFamily<ForumThreadDetailsNotifier, ForumThreadDetailsState, int>(() {
  return ForumThreadDetailsNotifier();
});
