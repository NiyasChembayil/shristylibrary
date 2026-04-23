class PostAuthor {
  final int id;
  final String username;
  final String? avatarUrl;

  PostAuthor({required this.id, required this.username, this.avatarUrl});

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    String? avatar = json['user_avatar'];
    if (avatar != null && avatar.isNotEmpty && !avatar.startsWith('http')) {
      avatar = 'https://srishty-backend.onrender.com$avatar';
    }
    if (avatar != null && avatar.startsWith('http://srishty-backend.onrender.com')) {
      avatar = avatar.replaceFirst('http://', 'https://');
    }
    return PostAuthor(
      id: json['user'] ?? 0,
      username: json['username'] ?? 'unknown',
      avatarUrl: avatar,
    );
  }

  PostAuthor copyWith({
    int? id,
    String? username,
    String? avatarUrl,
  }) {
    return PostAuthor(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class PostModel {
  final int id;
  final int userId;
  final String username;
  final String? userAvatar;
  final String text;
  final String postType; // REVIEW, QUOTE, OPINION, UPDATE
  final int? bookId;
  final String? bookTitle;
  final String? bookCover;
  final PostModel? parentPost;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final int repostsCount;
  final bool isLiked;

  PostModel({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.text,
    required this.postType,
    this.bookId,
    this.bookTitle,
    this.bookCover,
    this.parentPost,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
    required this.repostsCount,
    required this.isLiked,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    String? avatar = json['user_avatar'];
    if (avatar != null && avatar.isNotEmpty && !avatar.startsWith('http')) {
      avatar = 'https://srishty-backend.onrender.com$avatar';
    }
    String? cover = json['book_cover'];
    if (cover != null && cover.isNotEmpty && !cover.startsWith('http')) {
      cover = 'https://srishty-backend.onrender.com$cover';
    }
    
    // Always enforce HTTPS for images to avoid cleartext HTTP errors on mobile
    if (cover != null && cover.startsWith('http://srishty-backend.onrender.com')) {
      cover = cover.replaceFirst('http://', 'https://');
    }

    PostModel? parent;
    if (json['parent_post_data'] != null) {
      parent = PostModel.fromJson(json['parent_post_data']);
    }

    return PostModel(
      id: json['id'],
      userId: json['user'] ?? 0,
      username: json['username'] ?? 'unknown',
      userAvatar: avatar,
      text: json['text'] ?? '',
      postType: json['post_type'] ?? 'UPDATE',
      bookId: json['book'],
      bookTitle: json['book_title'],
      bookCover: cover,
      parentPost: parent,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      repostsCount: json['reposts_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
    );
  }

  PostModel copyWith({
    int? id,
    int? userId,
    String? username,
    String? userAvatar,
    String? text,
    String? postType,
    int? bookId,
    String? bookTitle,
    String? bookCover,
    PostModel? parentPost,
    DateTime? createdAt,
    int? likesCount,
    int? commentsCount,
    int? repostsCount,
    bool? isLiked,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatar: userAvatar ?? this.userAvatar,
      text: text ?? this.text,
      postType: postType ?? this.postType,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      bookCover: bookCover ?? this.bookCover,
      parentPost: parentPost ?? this.parentPost,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      repostsCount: repostsCount ?? this.repostsCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  String get postTypeLabel {
    switch (postType) {
      case 'REVIEW':
        return '⭐ Review';
      case 'QUOTE':
        return '💬 Quote';
      case 'OPINION':
        return '🗣 Opinion';
      case 'UPDATE':
        return '📖 Update';
      default:
        return '📝 Post';
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class PostCommentModel {
  final int id;
  final int userId;
  final String username;
  final String? userAvatar;
  final int postId;
  final String text;
  final DateTime createdAt;
  final int likesCount;
  final bool isLiked;

  PostCommentModel({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.postId,
    required this.text,
    required this.createdAt,
    this.likesCount = 0,
    this.isLiked = false,
  });

  factory PostCommentModel.fromJson(Map<String, dynamic> json) {
    String? avatar = json['user_avatar'];
    if (avatar != null && avatar.isNotEmpty && !avatar.startsWith('http')) {
      avatar = 'https://srishty-backend.onrender.com$avatar';
    }
    return PostCommentModel(
      id: json['id'],
      userId: json['user'] ?? 0,
      username: json['username'] ?? 'unknown',
      userAvatar: avatar,
      postId: json['post'] ?? 0,
      text: json['text'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      likesCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
    );
  }

  PostCommentModel copyWith({
    int? id,
    int? userId,
    String? username,
    String? userAvatar,
    int? postId,
    String? text,
    DateTime? createdAt,
    int? likesCount,
    bool? isLiked,
  }) {
    return PostCommentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatar: userAvatar ?? this.userAvatar,
      postId: postId ?? this.postId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
