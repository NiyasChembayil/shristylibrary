import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/post_model.dart';
import '../../../providers/post_provider.dart';
import '../post_detail_screen.dart';
import '../../profile/profile_screen.dart';
import '../../book/book_detail_screen.dart';
import '../../../providers/auth_provider.dart';
import '../create_post_screen.dart';

class PostCard extends ConsumerStatefulWidget {
  final PostModel post;
  const PostCard({super.key, required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  bool _showBigHeart = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (!widget.post.isLiked) {
      ref.read(postFeedProvider.notifier).toggleLike(widget.post);
    }
    setState(() => _showBigHeart = true);
    _heartController.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _showBigHeart = false);
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF14141E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author row
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(targetUserId: post.userId),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF6C63FF),
                          backgroundImage: post.userAvatar != null
                              ? NetworkImage(post.userAvatar!)
                              : null,
                          child: post.userAvatar == null
                              ? Text(
                                  post.username.isNotEmpty
                                      ? post.username[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                post.timeAgo,
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // 3-dot menu for owners
                        Consumer(
                          builder: (context, ref, _) {
                            final myUser = ref.watch(authProvider).profile;
                            if (myUser == null || myUser.userId != post.userId) {
                              return const SizedBox.shrink();
                            }
                            return PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                              color: const Color(0xFF1E1E2E),
                              onSelected: (val) async {
                                if (val == 'edit') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => CreatePostScreen(postToEdit: post)),
                                  );
                                } else if (val == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E1E2E),
                                      title: const Text('Delete Post?', style: TextStyle(color: Colors.white)),
                                      content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    ref.read(postFeedProvider.notifier).deletePost(post.id);
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')]),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [Icon(Icons.delete, color: Colors.redAccent, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.redAccent))]),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Repost (parent post)
                  if (post.parentPost != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '↩️ ${post.parentPost!.username}',
                            style: const TextStyle(
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            post.parentPost!.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Post text
                  if (post.text.isNotEmpty)
                    MentionRichText(
                      text: post.text,
                      onProfileTap: (id) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(targetUserId: int.tryParse(id)),
                          ),
                        );
                      },
                      onBookTap: (id) {
                        final bookId = int.tryParse(id);
                        if (bookId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookDetailScreen(
                                id: bookId,
                                // These will be fetched by the provider in BookDetailScreen if not provided
                                title: '', 
                                author: '',
                                coverUrl: '',
                                description: '',
                              ),
                            ),
                          );
                        }
                      },
                    ),

                  // Book card
                  if (post.bookTitle != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          if (post.bookCover != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                post.bookCover!,
                                width: 40,
                                height: 55,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 40,
                                  height: 55,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.book,
                                      color: Colors.white24, size: 20),
                                ),
                              ),
                            ),
                          if (post.bookCover != null) const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '📚 ${post.bookTitle}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  // Action bar
                  Row(
                    children: [
                      _ActionButton(
                        icon: post.isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: post.isLiked
                            ? const Color(0xFFFF6584)
                            : Colors.grey,
                        count: post.likesCount,
                        onTap: () async {
                          try {
                            await ref.read(postFeedProvider.notifier).toggleLike(post);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Login required to like posts'),
                                backgroundColor: Color(0xFFFF6584),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 20),
                      _ActionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        color: Colors.grey,
                        count: post.commentsCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PostDetailScreen(post: post)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      _ActionButton(
                        icon: Icons.repeat_rounded,
                        color: Colors.grey,
                        count: post.repostsCount,
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E2E),
                              title: const Text('Repost?',
                                  style: TextStyle(color: Colors.white)),
                              content: const Text(
                                'Share this post with your followers?',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Repost',
                                        style: TextStyle(
                                            color: Color(0xFF6C63FF)))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await ref.read(postFeedProvider.notifier).repost(post);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Login required to repost'),
                                  backgroundColor: Color(0xFF6C63FF),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Double-tap heart animation
            if (_showBigHeart)
              Positioned.fill(
                child: Center(
                  child: ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _heartController,
                      curve: Curves.elasticOut,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFFF6584),
                      size: 80,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
                color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MentionRichText — renders @username (purple) and @[Book Title] (gold) spans
// ─────────────────────────────────────────────────────────────────────────────

class MentionRichText extends StatelessWidget {
  final String text;
  final void Function(String id)? onProfileTap;
  final void Function(String id)? onBookTap;

  const MentionRichText({
    super.key,
    required this.text,
    this.onProfileTap,
    this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      _buildSpans(text),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        height: 1.5,
      ),
    );
  }

  TextSpan _buildSpans(String input) {
    final spans = <InlineSpan>[];
    // Matches structured tokens: @{ID|label} or @[ID|label]
    // Group 1: User ID, Group 2: Username
    // Group 3: Book ID, Group 4: Book Title
    final pattern = RegExp(r'@\{(\d+)\|([^}]+)\}|@\[(\d+)\|([^\]]+)\]');
    int lastEnd = 0;

    for (final match in pattern.allMatches(input)) {
      // Plain text before this match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: input.substring(lastEnd, match.start)));
      }

      final userId = match.group(1);
      final username = match.group(2);
      final bookId = match.group(3);
      final bookTitle = match.group(4);

      if (userId != null) {
        spans.add(TextSpan(
          text: '@$username',
          style: const TextStyle(
            color: Color(0xFF6C63FF),
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onProfileTap?.call(userId),
        ));
      } else if (bookId != null) {
        spans.add(TextSpan(
          text: '@$bookTitle',
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onBookTap?.call(bookId),
        ));
      }

      lastEnd = match.end;
    }

    // Trailing plain text
    if (lastEnd < input.length) {
      spans.add(TextSpan(text: input.substring(lastEnd)));
    }

    return TextSpan(children: spans);
  }
}

