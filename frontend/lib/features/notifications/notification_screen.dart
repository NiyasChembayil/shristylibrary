import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/notification_provider.dart';
import '../../providers/social_provider.dart';
import '../profile/profile_screen.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(notificationProvider.notifier).fetchNotifications();
      // Mark all as read to clear the badge
      ref.read(notificationProvider.notifier).markAllRead(ref);
      
      final notifications = ref.read(notificationProvider);
      // Initialize social statuses for the follow buttons
      for (var notif in notifications) {
        if (notif['action_type'] == 'FOLLOW' && notif['actor_name'] != null) {
          ref.read(socialProvider.notifier).setFollowingStatus(
            notif['actor_name'], 
            notif['is_following'] ?? false
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationProvider);
    final groupedNotifs = _groupNotifications(notifications);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => ref.read(notificationProvider.notifier).markAllRead(ref),
            icon: const Icon(Icons.done_all_rounded, color: Color(0xFF6C63FF)),
          ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: groupedNotifs.entries.map((entry) {
                if (entry.value.isEmpty) return const SizedBox.shrink();
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 10),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ...entry.value.map((notif) => _buildNotificationTile(notif)),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Map<String, List<dynamic>> _groupNotifications(List<dynamic> notifications) {
    final Map<String, List<dynamic>> groups = {
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Earlier': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sixDaysAgo = today.subtract(const Duration(days: 6));

    for (var notif in notifications) {
      if (notif['created_at'] == null) {
        groups['Today']!.add(notif);
        continue;
      }

      try {
        final date = DateTime.parse(notif['created_at']);
        final dayOnly = DateTime(date.year, date.month, date.day);

        if (dayOnly.isAtSameMomentAs(today)) {
          groups['Today']!.add(notif);
        } else if (dayOnly.isAtSameMomentAs(yesterday)) {
          groups['Yesterday']!.add(notif);
        } else if (dayOnly.isAfter(sixDaysAgo)) {
          groups['This Week']!.add(notif);
        } else {
          groups['Earlier']!.add(notif);
        }
      } catch (_) {
        groups['Earlier']!.add(notif);
      }
    }

    return groups;
  }

  Widget _buildNotificationTile(dynamic notif) {
    final timeAgo = _getTimeAgo(notif['created_at']);
    final actorName = notif['actor_name'] ?? 'System';
    final initial = actorName.isNotEmpty ? actorName[0].toUpperCase() : 'S';

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      color: notif['is_read'] ? Colors.transparent : Colors.white.withValues(alpha: 0.05),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF00D2FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (notif['actor'] != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ProfileScreen(targetUserId: notif['actor'])),
                  );
                }
              },
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
                  children: [
                    TextSpan(text: actorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: _getActionText(notif['action_type'])),
                    if (notif['book_title'] != null && notif['action_type'] != 'LIKE' && notif['action_type'] != 'POST_LIKE')
                      TextSpan(text: notif['book_title'], style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white70)),
                    if (notif['message'] != null && (notif['action_type'] == 'COMMENT' || notif['action_type'] == 'POST_COMMENT'))
                      TextSpan(text: ' "${notif['message']}"', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70)),
                    TextSpan(
                      text: '  $timeAgo',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Trailing Action/Indicator
          if (notif['action_type'] == 'FOLLOW')
            Consumer(
              builder: (context, ref, _) {
                final followingMap = ref.watch(socialProvider);
                final isFollowing = followingMap[notif['actor_name']] ?? notif['is_following'] ?? false;
                
                return ElevatedButton(
                  onPressed: () {
                    if (notif['actor_name'] != null && notif['actor_profile_id'] != null) {
                      ref.read(socialProvider.notifier).toggleFollow(
                        notif['actor_name'], 
                        notif['actor_profile_id']
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? Colors.white10 : const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isFollowing ? 'Following' : 'Follow Back', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                );
              }
            )
          else if (notif['action_type'] != 'FOLLOW')
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _getNotificationIcon(notif['action_type']),
                color: _getNotificationColor(notif['action_type']),
                size: 20,
              ),
            ),

            
          if (!notif['is_read'] && notif['action_type'] != 'FOLLOW' && notif['action_type'] != 'LIKE' && notif['action_type'] != 'COMMENT')
            Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 8), decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle)),
        ],
      ),
    );
  }

  String _getActionText(String? type) {
    switch (type) {
      case 'LIKE': return ' liked your book.';
      case 'POST_LIKE': return ' liked your post.';
      case 'POST_COMMENT_LIKE': return ' liked your comment.';
      case 'COMMENT': return ' commented:';
      case 'POST_COMMENT': return ' commented on your post.';
      case 'FOLLOW': return ' started following you.';
      case 'NEW_BOOK': return ' published a new book: ';
      case 'REPOST': return ' reposted your post.';
      default: return ' sent a notification. ';
    }
  }

  IconData _getNotificationIcon(String? type) {
    if (type == 'LIKE' || type == 'POST_LIKE' || type == 'POST_COMMENT_LIKE') return Icons.favorite_rounded;
    if (type == 'COMMENT' || type == 'POST_COMMENT') return Icons.comment_rounded;
    if (type == 'REPOST') return Icons.repeat_rounded;
    return Icons.auto_stories_rounded;
  }

  Color _getNotificationColor(String? type) {
    if (type == 'LIKE' || type == 'POST_LIKE' || type == 'POST_COMMENT_LIKE') return Colors.redAccent;
    if (type == 'COMMENT' || type == 'POST_COMMENT') return Colors.blueAccent;
    if (type == 'REPOST') return Colors.greenAccent;
    return Colors.purpleAccent;
  }

  String _getTimeAgo(String? timestamp) {
    if (timestamp == null) return '1h';
    try {
      final date = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 7) return '${diff.inDays ~/ 7}w';
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'Just now';
    } catch (_) {
      return '2h';
    }
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80, color: Colors.white10),
          SizedBox(height: 15),
          Text('All caught up!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white24)),
          Text('No new notifications for you.', style: TextStyle(color: Colors.white10)),
        ],
      ),
    );
  }
}
