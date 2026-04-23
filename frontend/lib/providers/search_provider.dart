import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/book_model.dart';
import '../models/profile_model.dart';
import 'package:dio/dio.dart';
import '../models/post_model.dart';

class SearchState {
  final List<BookModel> books;
  final List<ProfileModel> profiles;
  final List<BookModel> mostlyReadBooks;
  final String mostlyReadCategoryName;
  final List<BookModel> localHits;
  final List<BookModel> socialHits;
  final List<PostModel> trendingPosts;
  final bool isLoading;

  SearchState({
    required this.books,
    required this.profiles,
    this.mostlyReadBooks = const [],
    this.mostlyReadCategoryName = '',
    this.localHits = const [],
    this.socialHits = const [],
    this.trendingPosts = const [],
    this.isLoading = false,
  });

  factory SearchState.initial() => SearchState(
    books: [], 
    profiles: [], 
    mostlyReadBooks: [], 
    mostlyReadCategoryName: '', 
    localHits: [],
    socialHits: [],
    trendingPosts: []
  );
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.read(apiClientProvider));
});

class SearchNotifier extends StateNotifier<SearchState> {
  final ApiClient _apiClient;

  SearchNotifier(this._apiClient) : super(SearchState.initial());

  Future<void> searchAll(String query) async {
    if (query.isEmpty) {
      // Don't just reset, keep discovery data if it exists or re-fetch it
      fetchDiscovery();
      return;
    }
    
    state = SearchState(
      books: state.books, 
      profiles: state.profiles, 
      mostlyReadBooks: state.mostlyReadBooks,
      mostlyReadCategoryName: state.mostlyReadCategoryName,
      localHits: state.localHits,
      socialHits: state.socialHits,
      isLoading: true
    );
    
    try {
      final results = await Future.wait([
        _apiClient.dio.get('core/books/?search=$query'),
        _apiClient.dio.get('accounts/profile/?search=$query'),
      ]);

      final bookData = results[0].data['results'] as List? ?? [];
      final profileData = results[1].data['results'] as List? ?? [];

      state = SearchState(
        books: bookData.map((j) => BookModel.fromJson(j)).toList(),
        profiles: profileData.map((j) => ProfileModel.fromJson(j)).toList(),
        mostlyReadBooks: state.mostlyReadBooks,
        mostlyReadCategoryName: state.mostlyReadCategoryName,
        localHits: state.localHits,
        socialHits: state.socialHits,
        isLoading: false,
      );
    } catch (e) {
      state = SearchState(
        books: state.books, 
        profiles: state.profiles, 
        mostlyReadBooks: state.mostlyReadBooks,
        mostlyReadCategoryName: state.mostlyReadCategoryName,
        localHits: state.localHits,
        isLoading: false
      );
    }
  }

  Future<void> fetchDiscovery({String region = 'Global'}) async {
    state = SearchState(
      books: state.books, 
      profiles: state.profiles, 
      mostlyReadBooks: state.mostlyReadBooks,
      mostlyReadCategoryName: state.mostlyReadCategoryName,
      localHits: state.localHits,
      socialHits: state.socialHits,
      isLoading: true
    );

    try {
      // Fetch books and social trending separately to prevent one from breaking the other
      Response<dynamic>? bookResp;
      try { bookResp = await _apiClient.dio.get('core/books/discovery/?region=$region'); } catch(_) {}
      
      Response<dynamic>? socialResp;
      try { socialResp = await _apiClient.dio.get('social/posts/trending/'); } catch(_) {}

      final bookData = bookResp?.data;
      final socialData = socialResp?.data;

      if (bookData != null) {
        final mostlyRead = bookData['mostly_read']['books'] as List? ?? [];
        final localHits = bookData['local_hits'] as List? ?? [];

        state = SearchState(
          books: [], 
          profiles: [],
          mostlyReadBooks: mostlyRead.map((j) => BookModel.fromJson(j)).toList(),
          mostlyReadCategoryName: bookData['mostly_read']['category_name'] ?? 'Trending',
          localHits: localHits.map((j) => BookModel.fromJson(j)).toList(),
          socialHits: (bookData['social_hits'] as List? ?? []).map((j) => BookModel.fromJson(j)).toList(),
          trendingPosts: (socialData != null && socialData['trending_posts'] != null)
              ? (socialData['trending_posts'] as List).map((j) => PostModel.fromJson(j)).toList()
              : state.trendingPosts,
          isLoading: false,
        );
      } else {
        state = SearchState(
          books: state.books,
          profiles: state.profiles,
          mostlyReadBooks: state.mostlyReadBooks,
          isLoading: false
        );
      }
    } catch (e) {
      state = SearchState(
        books: state.books, 
        profiles: state.profiles, 
        mostlyReadBooks: state.mostlyReadBooks,
        isLoading: false
      );
    }
  }

  // Deprecated: Use searchAll
  Future<void> searchBooks(String query) => searchAll(query);

  Future<void> filterByCategory(String categorySlug) async {
    state = SearchState(books: state.books, profiles: state.profiles, isLoading: true);
    try {
      final response = await _apiClient.dio.get('core/books/?category=$categorySlug');
      final List data = response.data['results'] ?? [];
      state = SearchState(
        books: data.map((json) => BookModel.fromJson(json)).toList(),
        profiles: [],
        isLoading: false,
      );
    } catch (e) {
      state = SearchState(books: state.books, profiles: state.profiles, isLoading: false);
    }
  }
}
