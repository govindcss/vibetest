import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/forum_providers.dart';
import '../../repositories/event_repository.dart'; // Required for the createForumThread method
import '../../providers/event_providers.dart'; // For eventRepositoryProvider

// A new simple provider for managing the loading state of the creation form
final createThreadLoadingProvider = StateProvider<bool>((ref) => false);

class CreateForumThreadScreen extends ConsumerStatefulWidget {
  final String eventId;

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

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      ref.read(createThreadLoadingProvider.notifier).state = true;
      String? errorMsg;

      try {
        final newThread = await ref.read(eventRepositoryProvider).createForumThread(
              eventId: widget.eventId,
              title: _titleController.text.trim(),
              content: _contentController.text.trim().isNotEmpty ? _contentController.text.trim() : null,
            );

        // Add the new thread to the list in ForumThreadsNotifier
        ref.read(forumThreadsProvider(widget.eventId).notifier).addCreatedThread(newThread);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thread created successfully!')),
          );
          Navigator.pop(context); // Go back to the previous screen
        }
      } catch (e) {
        errorMsg = e.toString();
      } finally {
        if (mounted) {
          ref.read(createThreadLoadingProvider.notifier).state = false;
          if (errorMsg != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create thread: $errorMsg')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(createThreadLoadingProvider);

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
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Content (Optional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                minLines: 3,
                textAlignVertical: TextAlignVertical.top,
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Thread'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
