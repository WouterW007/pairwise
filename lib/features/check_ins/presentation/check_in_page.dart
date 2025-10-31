// lib/features/check_ins/presentation/check_in_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pairwise/features/check_ins/application/check_in_providers.dart';
import 'package:pairwise/features/check_ins/data/check_in_message.dart';
import 'package:pairwise/features/check_ins/data/check_in_repository.dart';
import 'package:pairwise/main.dart';

class CheckInPage extends ConsumerWidget {
  const CheckInPage({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(checkInMessagesStreamProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Date'),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('Loading session...'));
                }
                // Build the list of chat bubbles
                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(message: message);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: ${e.toString()}')),
            ),
          ),
          // The text input bar
          _MessageInputBar(sessionId: sessionId),
        ],
      ),
    );
  }
}

// A private widget for the chat bubble
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final CheckInMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = supabase.auth.currentUser?.id;

    // Determine bubble alignment
    final bool isFromApp = message.isFromApp;
    final bool isFromMe = message.userId == currentUserId;

    CrossAxisAlignment alignment = CrossAxisAlignment.start;
    Color bubbleColor = theme.colorScheme.surfaceVariant;
    EdgeInsets bubbleMargin = const EdgeInsets.fromLTRB(8, 8, 64, 8);

    if (isFromApp) {
      // App prompt [cite: 410]
      alignment = CrossAxisAlignment.center;
      bubbleColor = theme.colorScheme.primary.withOpacity(0.3);
      bubbleMargin = const EdgeInsets.symmetric(vertical: 10, horizontal: 32);
    } else if (isFromMe) {
      // Current user's reply [cite: 412]
      alignment = CrossAxisAlignment.end;
      bubbleColor = theme.colorScheme.primary;
      bubbleMargin = const EdgeInsets.fromLTRB(64, 8, 8, 8);
    }

    return Container(
      margin: bubbleMargin,
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                color: isFromMe
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// A private widget for the text input
class _MessageInputBar extends ConsumerStatefulWidget {
  const _MessageInputBar({required this.sessionId});
  final String sessionId;

  @override
  ConsumerState<_MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends ConsumerState<_MessageInputBar> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Get the current max order to increment it
      final messages = await ref.read(
        checkInMessagesStreamProvider(widget.sessionId).future,
      );
      final int nextOrder = messages.isNotEmpty
          ? messages.map((m) => m.order).reduce((a, b) => a > b ? a : b) + 1
          : 1;

      await ref.read(checkInRepositoryProvider).addMessage(
            sessionId: widget.sessionId,
            content: content,
            order: nextOrder,
          );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Type your response...',
                    border: InputBorder.none,
                    filled: false,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                onPressed: _isLoading ? null : _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
