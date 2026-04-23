import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post_model.dart';
import '../models/book_model.dart';
import '../models/profile_model.dart';
import '../core/api_client.dart';

// State
class PostFeedState {
  final List<PostModel> feed;
  final List<PostModel> trending;
  final List<PostModel> userPosts;
  final List<BookModel> popularBooks;
  final List<ProfileModel> topCreators;
  final bool isLoading;
  final bool isTrendingLoading;
  final bool isUserPostsLoading;
  final String? error;

  const PostFeedState({
    this.feed = const [],
    this.trending = const [],
    this.userPosts = const [],
    this.popularBooks = const [],
    this.topCreators = const [],
    this.isLoading = false,
    this.isTrendingLoading = false,
    this.isUserPostsLoading = false,
    this.error,
  });

  PostFeedState copyWith({
    List<PostModel>? feed,
    List<PostModel>? trending,
    List<PostModel>? userPosts,
    List<BookModel>? popularBooks,
    List<ProfileModel>? topCreators,
    bool? isLoading,
    bool? isTrendingLoading,
    bool? isUserPostsLoading,
    String? error,
  }) {
    return PostFeedState(
      feed: feed ?? this.feed,
      trending: trending ?? this.trending,
      userPosts: userPosts ?? this.userPosts,
      popularBooks: popularBooks ?? this.popularBooks,
      topCreators: topCreators ?? this.topCreators,
      isLoading: isLoading ?? this.isLoading,
      isTrendingLoading: isTrendingLoading ?? this.isTrendingLoading,
      isUserPostsLoading: isUserPostsLoading ?? this.isUserPostsLoading,
      error: error,
    );
  }
}

class PostFeedNotifier extends StateNotifier<PostFeedState> {
  final ApiClient _api;

  PostFeedNotifier(this._api) : super(const PostFeedState());

  Future<void> loadFeed() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await _api.dio.get('social/posts/feed/');
      final posts = (resp.data as List).map((j) => PostModel.fromJson(j)).toList();
      state = state.copyWith(feed: posts, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadTrending() async {
    state = state.copyWith(isTrendingLoading: true);
    try {
      final resp = await _api.dio.get('social/posts/trending/');
      final posts = (resp.data['trending_posts'] as List)
          .map((j) => PostModel.fromJson(j))
          .toList();
      final books = (resp.data['popular_books'] as List)
          .map((j) => BookModel.fromJson(j))
          .toList();
      final creators = (resp.data['top_creators'] as List)
          .map((j) => ProfileModel.fromJson(j))
          .toList();
          
      state = state.copyWith(
        trending: posts, 
        popularBooks: books,
        topCreators: creators,
        isTrendingLoading: false
      );
    } catch (e) {
      state = state.copyWith(isTrendingLoading: false);
    }
  }

  Future<void> loadUserPosts(int profileId) async {
    state = state.copyWith(isUserPostsLoading: true);
    try {
      // Assuming profileId corresponds to Django user id for simplicity here
      // Better to use a dedicated profile_posts action if they differ
      final resp = await _api.dio.get('social/posts/user_posts/?user_id=$profileId');
      final posts = (resp.data as List).map((j) => PostModel.fromJson(j)).toList();
      state = state.copyWith(userPosts: posts, isUserPostsLoading: false);
    } catch (e) {
      state = state.copyWith(isUserPostsLoading: false);
    }
  }

  Future<void> createPost({
    required String text,
    required String postType,
    int? bookId,
  }) async {
    try {
      final body = {'text': text, 'post_type': postType};
      if (bookId != null) body['book'] = bookId.toString();
      final resp = await _api.dio.post('social/posts/', data: body);
      final newPost = PostModel.fromJson(resp.data);
      state = state.copyWith(feed: [newPost, ...state.feed]);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleLike(PostModel post) async {
    final oldIsLiked = post.isLiked;
    final newIsLiked = !oldIsLiked;
    final newLikesCount = newIsLiked ? post.likesCount + 1 : post.likesCount - 1;

    // Helper to update a post in a list
    List<PostModel> updateList(List<PostModel> list) {
      return list.map((p) => p.id == post.id ? p.copyWith(isLiked: newIsLiked, likesCount: newLikesCount) : p).toList();
    }

    // Optimistic update
    state = state.copyWith(
      feed: updateList(state.feed),
      userPosts: updateList(state.userPosts),
    );

    try {
      final action = oldIsLiked ? 'unlike' : 'like';
      await _api.dio.post('social/posts/${post.id}/$action/');
    } catch (_) {
      // Revert if API fails
      state = state.copyWith(
        feed: updateList(state.feed),
        userPosts: updateList(state.userPosts),
      );
    }
  }

  Future<bool> toggleCommentLike(PostCommentModel comment) async {
    final originalStatus = comment.isLiked;
    // We don't have a global comment list in state (they are fetched per post),
    // so the UI should handle the optimistic update locally or we just return the new model.
    try {
      final endpoint = originalStatus 
          ? 'social/post-comments/${comment.id}/unlike/' 
          : 'social/post-comments/${comment.id}/like/';
      
      await _api.dio.post(endpoint);
      // Backend returns {'likes_count': X}
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> repost(PostModel post) async {
    try {
      await _api.dio.post('social/posts/${post.id}/repost/');
      await loadFeed();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePost(int postId) async {
    try {
      await _api.dio.delete('social/posts/$postId/');
      
      // Update local state by removing the deleted post
      state = state.copyWith(
        feed: state.feed.where((p) => p.id != postId).toList(),
        userPosts: state.userPosts.where((p) => p.id != postId).toList(),
        trending: state.trending.where((p) => p.id != postId).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePost(int postId, String text) async {
    try {
      final resp = await _api.dio.patch('social/posts/$postId/', data: {'text': text});
      final updatedPost = PostModel.fromJson(resp.data);
      
      // Update local state with the new post content
      List<PostModel> updateList(List<PostModel> list) {
        return list.map((p) => p.id == postId ? updatedPost : p).toList();
      }
      
      state = state.copyWith(
        feed: updateList(state.feed),
        userPosts: updateList(state.userPosts),
        trending: updateList(state.trending),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<PostCommentModel>> fetchComments(int postId) async {
    final resp = await _api.dio.get('social/post-comments/?post=$postId');
    List data;
    if (resp.data is Map && resp.data.containsKey('results')) {
      data = resp.data['results'] as List;
    } else {
      data = resp.data as List;
    }
    return data.map((j) => PostCommentModel.fromJson(j)).toList();
  }

  Future<void> addComment(int postId, String text) async {
    await _api.dio.post('social/post-comments/', data: {'post': postId, 'text': text});
  }

  /// Called by WebSocket service to update post counts in real-time
  void updatePostActivity(int postId, int likesCount, int commentsCount) {
    List<PostModel> updateList(List<PostModel> list) {
      bool found = false;
      final newList = list.map((p) {
        if (p.id == postId) {
          found = true;
          return p.copyWith(likesCount: likesCount, commentsCount: commentsCount);
        }
        return p;
      }).toList();
      return found ? newList : list;
    }

    state = state.copyWith(
      feed: updateList(state.feed),
      userPosts: updateList(state.userPosts),
      trending: updateList(state.trending),
    );
  }
}

final postFeedProvider = StateNotifierProvider<PostFeedNotifier, PostFeedState>((ref) {
  final api = ref.watch(apiClientProvider);
  return PostFeedNotifier(api);
});
