import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/forum_providers.dart';
import '../../repositories/event_repository.dart';
import '../../providers/event_providers.dart'; // For eventRepositoryProvider

/// A provider to manage the loading state specifically for the thread creation form.
/// This helps in showing a loading indicator on the submit button without affecting
/// other parts of the UI that might depend on broader loading states.
final _createThreadLoadingProvider = StateProvider<bool>((ref) => false);

/// A screen that allows users to create a new forum thread for a specific event.
///
/// It takes an `eventId` to associate the new thread with the correct event.
/// Uses [eventRepositoryProvider] to create the thread and [forumThreadsProvider]
/// to optimistically update the list of threads upon successful creation.
class CreateForumThreadScreen extends ConsumerStatefulWidget {
  /// The unique identifier of the event for which to create a new forum thread.
  final String eventId;

  /// Constructs a [CreateForumThreadScreen].
  /// Requires an [eventId].
  const CreateForumThreadScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  ConsumerState<CreateForumThreadScreen> createState() => _CreateForumThreadScreenState();
}

class _CreateForumThreadScreenState extends ConsumerState<CreateForumThreadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// Handles the submission of the new forum thread form.
  ///
  /// Validates the form fields, then calls the [EventRepository.createForumThread] method.
  /// On success, it optimistically updates the local list of threads using
  /// [ForumThreadsNotifier.addCreatedThread] and navigates back.
  /// Shows a [SnackBar] for success or failure messages.
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      ref.read(_createThreadLoadingProvider.notifier).state = true;
      String? errorMsg;

      try {
        final newThread = await ref.read(eventRepositoryProvider).createForumThread(
              eventId: widget.eventId,
              title: _titleController.text.trim(),
              // Store null if content is empty, otherwise store trimmed content
              content: _contentController.text.trim().isNotEmpty ? _contentController.text.trim() : null,
            );

        // Optimistically add the new thread to the list displayed on the previous screen.
        ref.read(forumThreadsProvider(widget.eventId).notifier).addCreatedThread(newThread);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thread created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Go back after successful creation
        }
      } catch (e) {
        errorMsg = e.toString();
      } finally {
        if (mounted) {
          ref.read(_createThreadLoadingProvider.notifier).state = false;
          if (errorMsg != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to create thread: $errorMsg'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = ref.watch(_createThreadLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Forum Thread'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter a concise title for your thread',
                  border: OutlineInputBorder(),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  if (value.trim().length < 5) {
                     return 'Title must be at least 5 characters long';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20.0),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Content (Optional)',
                  hintText: 'Provide more details or your initial post here...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                maxLines: 10,
                minLines: 5,
                textAlignVertical: TextAlignVertical.top,
                // No validator needed for optional content, but could add length limits if desired.
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 24, // Consistent height with text
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)
                      )
                    : const Text('Create Thread'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
