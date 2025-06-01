import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forum_thread.dart';
import '../models/forum_reply.dart';
import '../repositories/event_repository.dart';
// Assuming eventRepositoryProvider is defined in event_providers.dart or similar
import 'event_providers.dart';


// --- Forum Threads List (per Event) ---

class ForumThreadsState {
  final List<ForumThread> threads;
  final bool isLoadingNextPage;
  final bool hasReachedMax;
  final int currentPage;
  final String? errorMessage;

  ForumThreadsState({
    this.threads = const [],
    this.isLoadingNextPage = false,
    this.hasReachedMax = false,
    this.currentPage = 0,
    this.errorMessage,
  });

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

class ForumThreadsNotifier extends FamilyAsyncNotifier<ForumThreadsState, String> {
  static const int _pageSize = 15;
  String get _eventId => arg;

  Future<List<ForumThread>> _fetchPage(int page) async {
    final repository = ref.read(eventRepositoryProvider);
    return await repository.fetchForumThreads(
      eventId: _eventId,
      page: page,
      pageSize: _pageSize,
    );
  }

  @override
  Future<ForumThreadsState> build(String eventId) async {
    final initialThreads = await _fetchPage(0);
    return ForumThreadsState(
      threads: initialThreads,
      currentPage: 0,
      hasReachedMax: initialThreads.length < _pageSize,
    );
  }

  Future<void> fetchNextPage() async {
    final previousState = state.value;
    if (previousState == null || previousState.isLoadingNextPage || previousState.hasReachedMax) {
      return;
    }
    state = AsyncData(previousState.copyWith(isLoadingNextPage: true, clearErrorMessage: true));
    try {
      final nextPage = previousState.currentPage + 1;
      final newThreads = await _fetchPage(nextPage);
      state = AsyncData(previousState.copyWith(
        threads: [...previousState.threads, ...newThreads],
        currentPage: nextPage,
        isLoadingNextPage: false,
        hasReachedMax: newThreads.length < _pageSize,
      ));
    } catch (e) {
      state = AsyncData(previousState.copyWith(isLoadingNextPage: false, errorMessage: e.toString()));
    }
  }

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

  // Method to add a newly created thread to the beginning of the list
  void addCreatedThread(ForumThread newThread) {
    final previousState = state.value;
    if (previousState != null) {
      state = AsyncData(previousState.copyWith(
        threads: [newThread, ...previousState.threads],
      ));
    }
  }
}

final forumThreadsProvider = AsyncNotifierProviderFamily<ForumThreadsNotifier, ForumThreadsState, String>(() {
  return ForumThreadsNotifier();
});


// --- Forum Thread Details & Replies (per Thread) ---

class ForumThreadDetailsState {
  final ForumThread? threadDetails;
  final List<ForumReply> replies;
  final bool isLoadingNextRepliesPage;
  final bool hasReachedMaxReplies;
  final int currentRepliesPage;
  final bool isPostingReply;
  final String? errorMessage; // For general errors or reply posting errors

  ForumThreadDetailsState({
    this.threadDetails,
    this.replies = const [],
    this.isLoadingNextRepliesPage = false,
    this.hasReachedMaxReplies = false,
    this.currentRepliesPage = 0,
    this.isPostingReply = false,
    this.errorMessage,
  });

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

class ForumThreadDetailsNotifier extends FamilyAsyncNotifier<ForumThreadDetailsState, int> {
  static const int _repliesPageSize = 15;
  int get _threadId => arg;

  Future<ForumThreadDetailsState> _fetchInitialData() async {
    final repository = ref.read(eventRepositoryProvider);
    final thread = await repository.fetchForumThreadDetails(threadId: _threadId);
    final initialReplies = await repository.fetchForumReplies(
      threadId: _threadId,
      page: 0,
      pageSize: _repliesPageSize,
    );
    return ForumThreadDetailsState(
      threadDetails: thread,
      replies: initialReplies,
      currentRepliesPage: 0,
      hasReachedMaxReplies: initialReplies.length < _repliesPageSize,
    );
  }

  @override
  Future<ForumThreadDetailsState> build(int threadId) async {
    return _fetchInitialData();
  }

  Future<void> fetchNextRepliesPage() async {
    final previousState = state.value;
    if (previousState == null || previousState.isLoadingNextRepliesPage || previousState.hasReachedMaxReplies) {
      return;
    }
    state = AsyncData(previousState.copyWith(isLoadingNextRepliesPage: true, clearErrorMessage: true));
    try {
      final nextPage = previousState.currentRepliesPage + 1;
      final newReplies = await ref.read(eventRepositoryProvider).fetchForumReplies(
        threadId: _threadId,
        page: nextPage,
        pageSize: _repliesPageSize,
      );
      state = AsyncData(previousState.copyWith(
        replies: [...previousState.replies, ...newReplies],
        currentRepliesPage: nextPage,
        isLoadingNextRepliesPage: false,
        hasReachedMaxReplies: newReplies.length < _repliesPageSize,
      ));
    } catch (e) {
      state = AsyncData(previousState.copyWith(isLoadingNextRepliesPage: false, errorMessage: e.toString()));
    }
  }

  Future<void> addReply(String message, {int? parentReplyId}) async {
    final previousState = state.value;
    if (previousState == null || previousState.isPostingReply) return;

    state = AsyncData(previousState.copyWith(isPostingReply: true, clearErrorMessage: true));
    try {
      final newReply = await ref.read(eventRepositoryProvider).createForumReply(
        threadId: _threadId,
        message: message,
        parentReplyId: parentReplyId,
      );
      // Add reply to the list optimistically or re-fetch. Here, adding optimistically.
      state = AsyncData(previousState.copyWith(
        replies: [...previousState.replies, newReply],
        isPostingReply: false,
      ));
      // Also, refresh the parent thread in the list view by updating its 'updated_at'
      // This can be done by finding the eventId from threadDetails and refreshing forumThreadsProvider
      // For now, this is an indirect effect handled by the DB trigger.
      // Consider a mechanism to update the specific thread in ForumThreadsNotifier if needed.
      final eventId = previousState.threadDetails?.eventId;
      if (eventId != null) {
        ref.invalidate(forumThreadsProvider(eventId)); // Invalidate to refresh list
      }


    } catch (e) {
      state = AsyncData(previousState.copyWith(isPostingReply: false, errorMessage: e.toString()));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await _fetchInitialData());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final forumThreadDetailsProvider = AsyncNotifierProviderFamily<ForumThreadDetailsNotifier, ForumThreadDetailsState, int>(() {
  return ForumThreadDetailsNotifier();
});
