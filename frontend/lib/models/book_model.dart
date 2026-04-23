class BookModel {
  final int id;
  final String title;
  final String authorName;
  final String categoryName;
  final String coverUrl;
  final String description;
  final double price;
  final int likesCount;
  final int totalReads;
  final List<ChapterModel> chapters;
  final List<String> pages;
  final bool isInLibrary;
  final bool isLiked;
  final int downloadsCount;

  final int authorProfileId;
  final bool isAuthorFollowing;

  BookModel({
    required this.id,
    required this.title,
    required this.authorName,
    required this.categoryName,
    required this.authorProfileId,
    required this.isAuthorFollowing,
    required this.coverUrl,
    required this.description,
    required this.price,
    required this.likesCount,
    required this.totalReads,
    required this.chapters,
    this.pages = const [],
    this.isInLibrary = false,
    this.isLiked = false,
    this.downloadsCount = 0,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    String cover = json['cover'] ?? '';
    
    // If the URL is already absolute (starts with http), leave it alone.
    // Otherwise, if it starts with /, prepend the backend domain.
    if (cover.isNotEmpty && !cover.startsWith('http')) {
      // In production, the media host is srishty-backend.onrender.com
      cover = 'https://srishty-backend.onrender.com${cover.startsWith('/') ? '' : '/'}$cover';
    } else {
      cover = 'https://placehold.co/400x600?text=No+Cover';
    }
    
    // Always enforce HTTPS for images to avoid cleartext HTTP errors on mobile
    if (cover.startsWith('http://srishty-backend.onrender.com')) {
      cover = cover.replaceFirst('http://', 'https://');
    }

    return BookModel(
      id: json['id'],
      title: json['title'] ?? 'Untitled',
      authorName: json['author_name'] ?? 'Unknown Author',
      categoryName: json['category_name'] ?? 'Novel',
      authorProfileId: json['author_profile_id'] ?? 0,
      isAuthorFollowing: json['is_author_following'] ?? false,
      coverUrl: cover,
      description: json['description'] ?? '',
      price: 0.0, // Platform is free
      likesCount: json['likes_count'] ?? 0,
      totalReads: json['total_reads'] ?? 0,
      isInLibrary: json['is_in_library'] ?? false,
      isLiked: json['is_liked'] ?? false,
      downloadsCount: json['downloads_count'] ?? 0,
      chapters: (json['chapters'] as List? ?? [])
          .map((c) => ChapterModel.fromJson(c))
          .toList(),
      pages: (json['pages'] as List? ?? [])
          .map((p) => p.toString())
          .toList(),
    );
  }

  BookModel copyWith({
    int? id,
    String? title,
    String? authorName,
    String? categoryName,
    int? authorProfileId,
    bool? isAuthorFollowing,
    String? coverUrl,
    String? description,
    double? price,
    int? likesCount,
    int? totalReads,
    List<ChapterModel>? chapters,
    List<String>? pages,
    bool? isInLibrary,
    bool? isLiked,
    int? downloadsCount,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      authorName: authorName ?? this.authorName,
      categoryName: categoryName ?? this.categoryName,
      authorProfileId: authorProfileId ?? this.authorProfileId,
      isAuthorFollowing: isAuthorFollowing ?? this.isAuthorFollowing,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      price: price ?? this.price,
      likesCount: likesCount ?? this.likesCount,
      totalReads: totalReads ?? this.totalReads,
      chapters: chapters ?? this.chapters,
      pages: pages ?? this.pages,
      isInLibrary: isInLibrary ?? this.isInLibrary,
      isLiked: isLiked ?? this.isLiked,
      downloadsCount: downloadsCount ?? this.downloadsCount,
    );
  }
}

class ChapterModel {
  final int id;
  final String title;
  final String content;
  final String? audioUrl;

  ChapterModel({
    required this.id,
    required this.title,
    required this.content,
    this.audioUrl,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    String? audio = json['audio_file'];
    if (audio != null && audio.startsWith('http://srishty-backend.onrender.com')) {
      audio = audio.replaceFirst('http://', 'https://');
    }

    return ChapterModel(
      id: json['id'],
      title: json['title'],
      content: json['content'] ?? '',
      audioUrl: audio,
    );
  }
}
