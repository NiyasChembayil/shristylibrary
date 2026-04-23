import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/post_model.dart';
import '../../providers/post_provider.dart';
import 'widgets/post_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final PostModel post;
  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  List<PostCommentModel> _comments = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final comments = await ref
          .read(postFeedProvider.notifier)
          .fetchComments(widget.post.id);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Could not load comments. Tap to retry.';
      });
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(postFeedProvider.notifier).addComment(widget.post.id, text);
      _commentCtrl.clear();
      await _loadComments();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Login required to comment'),
          backgroundColor: Color(0xFF6C63FF),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A12),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                // The post itself
                PostCard(post: widget.post),

                // Comments section header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF6C63FF), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Comments (${_comments.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C63FF)),
                    ),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: GestureDetector(
                        onTap: _loadComments,
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFFFF6584), fontSize: 14),
                        ),
                      ),
                    ),
                  )
                else if (_comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No comments yet.\nBe the first to reply!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 14, height: 1.5),
                      ),
                    ),
                  )
                else
                  ..._comments.map((c) => _CommentTile(
                    comment: c,
                    onLike: () => _toggleCommentLike(c),
                  )),
              ],
            ),
          ),

          // Comment input
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF14141E),
              border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFF1E1E2E),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSending ? null : _sendComment,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleCommentLike(PostCommentModel comment) async {
    final original = comment;
    setState(() {
      final index = _comments.indexWhere((c) => c.id == comment.id);
      if (index != -1) {
        _comments[index] = comment.copyWith(
          isLiked: !comment.isLiked,
          likesCount: comment.isLiked ? (comment.likesCount - 1).clamp(0, 999999) : comment.likesCount + 1,
        );
      }
    });

    final messenger = ScaffoldMessenger.of(context);
    final success = await ref.read(postFeedProvider.notifier).toggleCommentLike(original);
    if (!success) {
      setState(() {
        final index = _comments.indexWhere((c) => c.id == comment.id);
        if (index != -1) {
          _comments[index] = original;
        }
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to update like')),
      );
    }
  }
}

class _CommentTile extends StatelessWidget {
  final PostCommentModel comment;
  final VoidCallback onLike;
  const _CommentTile({required this.comment, required this.onLike});

  String get _timeAgo {
    final diff = DateTime.now().difference(comment.createdAt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF6C63FF),
            backgroundImage: comment.userAvatar != null
                ? NetworkImage(comment.userAvatar!)
                : null,
            child: comment.userAvatar == null
                ? Text(
                    comment.username.isNotEmpty
                        ? comment.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF14141E),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _timeAgo,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comment.text,
                    style: TextStyle(color: Colors.grey[300], fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: onLike,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            comment.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: comment.isLiked ? const Color(0xFFFF6584) : Colors.white38,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            comment.likesCount > 0 ? '${comment.likesCount}' : 'Like',
                            style: TextStyle(
                              color: comment.isLiked ? const Color(0xFFFF6584) : Colors.white38,
                              fontSize: 12,
                              fontWeight: comment.isLiked ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
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
