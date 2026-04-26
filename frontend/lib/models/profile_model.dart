class ProfileModel {
  final int id;
  final String username;
  final String role;
  final String bio;
  final String? avatar;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final bool isPrivate;
  final bool notifyNewFollower;
  final bool notifyLikes;
  final bool notifyComments;
  final bool notifyNewBooks;
  final double fontSize;
  final String readerTheme;
  final double playbackSpeed;
  final int userId;
  final String? email;
  final bool isVerified;

  ProfileModel({
    required this.id,
    required this.username,
    required this.role,
    required this.bio,
    this.avatar,
    required this.followersCount,
    required this.followingCount,
    this.isFollowing = false,
    required this.userId,
    this.email,
    this.isPrivate = false,
    this.notifyNewFollower = true,
    this.notifyLikes = true,
    this.notifyComments = true,
    this.notifyNewBooks = true,
    this.fontSize = 16.0,
    this.readerTheme = 'Dark',
    this.playbackSpeed = 1.0,
    this.isVerified = false,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    // The profile endpoint nests data; handle both flat and nested user data
    final user = json['user'] as Map<String, dynamic>?;

    return ProfileModel(
      id: json['id'] ?? 0,
      username: user?['username'] ?? json['username'] ?? 'User',
      role: json['role'] ?? 'reader',
      bio: json['bio'] ?? '',
      avatar: _fixAvatarUrl(json['avatar']),
      // 'followed_by' is the correct field name on the model
      followersCount: (json['followed_by'] as List?)?.length ?? json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      isFollowing: json['is_following'] ?? false,
      userId: json['user_id'] ?? json['user']?['id'] ?? 0,
      email: user?['email'] ?? json['email'],
      isPrivate: json['is_private'] ?? false,
      notifyNewFollower: json['notify_new_follower'] ?? true,
      notifyLikes: json['notify_likes'] ?? true,
      notifyComments: json['notify_comments'] ?? true,
      notifyNewBooks: json['notify_new_books'] ?? true,
      fontSize: (json['font_size'] as num?)?.toDouble() ?? 16.0,
      readerTheme: json['reader_theme'] ?? 'Dark',
      playbackSpeed: (json['playback_speed'] as num?)?.toDouble() ?? 1.0,
      isVerified: json['is_verified'] ?? false,
    );
  }

  static String? _fixAvatarUrl(String? url) {
    if (url == null || url.isEmpty) return url;
    if (!url.startsWith('http')) {
      url = 'https://srishty-backend.onrender.com$url';
    } else if (url.startsWith('http://srishty-backend.onrender.com')) {
      url = url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'bio': bio,
      'avatar': avatar,
      'followers_count': followersCount,
      'following_count': followingCount,
      'user_id': userId,
      'email': email,
      'is_private': isPrivate,
      'notify_new_follower': notifyNewFollower,
      'notify_likes': notifyLikes,
      'notify_comments': notifyComments,
      'notify_new_books': notifyNewBooks,
      'font_size': fontSize,
      'reader_theme': readerTheme,
      'playback_speed': playbackSpeed,
      'is_verified': isVerified,
    };
  }
}
