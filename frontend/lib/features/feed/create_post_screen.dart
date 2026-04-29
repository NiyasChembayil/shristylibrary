import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/post_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/post_model.dart';
import '../../providers/mention_provider.dart';
import '../../widgets/mention_overlay.dart';
import '../../widgets/mention_text_controller.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final PostModel? postToEdit;
  const CreatePostScreen({super.key, this.postToEdit});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final MentionTextEditingController _textCtrl = MentionTextEditingController();
  bool _isPosting = false;
  int _charCount = 0;

  static const int _maxChars = 500;

  @override
  void initState() {
    super.initState();
    if (widget.postToEdit != null) {
      _textCtrl.text = widget.postToEdit!.text;
      _charCount = _textCtrl.text.length;
    }
    _textCtrl.addListener(() {
      setState(() => _charCount = _textCtrl.text.length);
      _onTextChanged();
    });
  }

  /// Detects if the cursor is immediately after an @ token and triggers mention search.
  void _onTextChanged() {
    final text = _textCtrl.text;
    final cursor = _textCtrl.selection.baseOffset;
    if (cursor < 0) return;

    final textBeforeCursor = text.substring(0, cursor);
    // Match a trailing @word — e.g. "Hello @niy"
    final match = RegExp(r'@(\w*)$').firstMatch(textBeforeCursor);
    if (match != null) {
      final query = match.group(1) ?? '';
      ref.read(mentionProvider.notifier).search(query);
    } else {
      ref.read(mentionProvider.notifier).hide();
    }
  }

  /// Inserts the selected mention text in place of the partial @xxx token.
  void _insertMention(String id, String label) {
    final text = _textCtrl.text;
    final cursor = _textCtrl.selection.baseOffset.clamp(0, text.length);
    final textBeforeCursor = text.substring(0, cursor);

    // Find where the @ that triggered this suggestion starts
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex < 0) return;

    // Build the structured token: @{ID|label} or @[ID|label]
    late String token;
    final cleanLabel = label.startsWith('@') ? label.substring(1) : label;
    if (cleanLabel.startsWith('[') && cleanLabel.endsWith(']')) {
      // It's a book: @[ID|Title]
      final title = cleanLabel.substring(1, cleanLabel.length - 1);
      token = '@[$id|$title]';
    } else {
      // It's a user: @{ID|username}
      token = '@{$id|$cleanLabel}';
    }

    final newText =
        '${text.substring(0, atIndex)}$token ${text.substring(cursor)}';
    final newCursor = atIndex + token.length + 1;

    _textCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    ref.read(mentionProvider.notifier).hide();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something to post!')),
      );
      return;
    }
    setState(() => _isPosting = true);
    try {
      if (widget.postToEdit != null) {
        await ref.read(postFeedProvider.notifier).updatePost(
              widget.postToEdit!.id,
              text,
            );
      } else {
        await ref.read(postFeedProvider.notifier).createPost(
              text: text,
              postType: 'UPDATE', // Default type
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final username = authState.profile?.username ?? 'You';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A12),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.postToEdit != null ? 'Edit Post' : 'New Post',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _post,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(widget.postToEdit != null ? 'Save' : 'Post',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Mention dropdown sits above the scroll area ──────────
          Consumer(
            builder: (context, ref, _) {
              final visible = ref.watch(mentionProvider).isVisible;
              if (!visible) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: MentionOverlay(
                  onMentionSelected: _insertMention,
                ),
              );
            },
          ),
          // ── Scrollable compose body ──────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author row + text field
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF6C63FF).withOpacity(0.3),
                        child: Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          autofocus: true,
                          maxLines: null,
                          maxLength: _maxChars,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, height: 1.5),
                          decoration: InputDecoration(
                            hintText: "What's on your mind?",
                            hintStyle: TextStyle(
                                color: Colors.grey[600], fontSize: 15, height: 1.5),
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Char count
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$_charCount / $_maxChars',
                      style: TextStyle(
                        color: _charCount > _maxChars * 0.9
                            ? Colors.red
                            : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: Colors.white.withOpacity(0.08)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
