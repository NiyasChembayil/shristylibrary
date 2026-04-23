import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/social_provider.dart';
import '../providers/auth_provider.dart';

/// Reusable follow button for authors.
/// Communicates with the 'social/follows/' API endpoint.
class FollowButton extends ConsumerStatefulWidget {
  final String authorUsername;
  final int? authorProfileId;
  final bool initialIsFollowing;
  final bool isCompact;

  const FollowButton({
    super.key,
    required this.authorUsername,
    this.authorProfileId,
    this.initialIsFollowing = false,
    this.isCompact = false,
  });

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Seed the global provider with the initial status from the parent widget
    Future.microtask(() {
      if (mounted) {
        ref.read(socialProvider.notifier).setFollowingStatus(
          widget.authorUsername, 
          widget.initialIsFollowing,
        );
      }
    });
  }

  Future<void> _toggleFollow() async {
    if (_isLoading || widget.authorProfileId == null) return;
    
    setState(() => _isLoading = true);
    try {
      await ref.read(socialProvider.notifier).toggleFollow(
        widget.authorUsername,
        widget.authorProfileId!,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final followingMap = ref.watch(socialProvider);
    
    // Don't show follow button if it's the current user themselves
    if (authState.profile?.username == widget.authorUsername) {
      return const SizedBox.shrink();
    }

    final isFollowing = followingMap[widget.authorUsername] ?? widget.initialIsFollowing;

    return OutlinedButton(
      onPressed: _isLoading ? null : _toggleFollow,
      style: OutlinedButton.styleFrom(
        backgroundColor: isFollowing ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        foregroundColor: isFollowing ? Colors.white70 : const Color(0xFF6C63FF),
        side: BorderSide(
          color: isFollowing ? Colors.white24 : const Color(0xFF6C63FF),
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(
          horizontal: widget.isCompact ? 8 : 16,
          vertical: 0,
        ),
        minimumSize: Size(widget.isCompact ? 60 : 100, widget.isCompact ? 30 : 40),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isFollowing) const Icon(Icons.check_rounded, size: 14),
                if (isFollowing) const SizedBox(width: 4),
                Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    fontSize: widget.isCompact ? 11 : 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }
}
