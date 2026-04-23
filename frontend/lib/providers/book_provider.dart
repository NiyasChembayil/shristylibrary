import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/book_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'my_books_provider.dart';

// --- State class to distinguish loading / loaded / empty / error ---
enum BookFeedStatus { initial, loading, loaded, empty, error }

class BookFeedState {
  final BookFeedStatus status;
  final List<BookModel> books;
  final String? error;

  const BookFeedState({
    required this.status,
    this.books = const [],
    this.error,
  });

  BookFeedState copyWith({
    BookFeedStatus? status,
    List<BookModel>? books,
    String? error,
  }) {
    return BookFeedState(
      status: status ?? this.status,
      books: books ?? this.books,
      error: error ?? this.error,
    );
  }
}

final bookProvider = StateNotifierProvider<BookNotifier, BookFeedState>((ref) {
  return BookNotifier(ref.read(apiClientProvider));
});

class BookNotifier extends StateNotifier<BookFeedState> {
  final ApiClient _apiClient;

  BookNotifier(this._apiClient) : super(const BookFeedState(status: BookFeedStatus.initial)) {
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_books');
    if (cached != null) {
      try {
        final List decoded = jsonDecode(cached);
        final books = decoded.map((j) => BookModel.fromJson(j)).toList();
        if (books.isNotEmpty) {
          state = BookFeedState(status: BookFeedStatus.loaded, books: books);
        }
      } catch (_) {
        // Corrupt cache — ignore and fetch fresh
      }
    }
  }

  Future<void> fetchBooks() async {
    // Only show loading spinner if we have no cached data yet
    if (state.books.isEmpty) {
      state = const BookFeedState(status: BookFeedStatus.loading);
    }
    try {
      final response = await _apiClient.dio.get('core/books/');
      final dynamic responseData = response.data;

      // Handle both paginated { results: [...] } and plain list responses
      final List rawList = responseData is Map ? (responseData['results'] ?? []) : responseData as List;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_books', jsonEncode(rawList));

      final books = rawList.map((json) => BookModel.fromJson(json)).toList();
      state = books.isEmpty
          ? const BookFeedState(status: BookFeedStatus.empty)
          : BookFeedState(status: BookFeedStatus.loaded, books: books);
    } catch (e) {
      // If we already have cached books, stay on loaded — don't show error
      if (state.books.isNotEmpty) {
        state = BookFeedState(status: BookFeedStatus.loaded, books: state.books);
      } else {
        state = BookFeedState(status: BookFeedStatus.error, error: e.toString());
      }
    }
  }

  Future<void> likeBook(int id, WidgetRef ref) async {
    try {
      await _apiClient.dio.post('social/likes/', data: {'book': id});
      // Refresh the specific book detail provider to show the new count and state
      ref.invalidate(currentBookProvider(id));
    } catch (e) {
      // Silence error if liking fails
    }
  }

  Future<void> recordRead(int id) async {
    try {
      await _apiClient.dio.post('core/books/$id/record_read/');
      
      // Update local state for immediate feedback
      final updatedBooks = state.books.map((book) {
        if (book.id == id) {
          return book.copyWith(totalReads: book.totalReads + 1);
        }
        return book;
      }).toList();
      
      state = state.copyWith(books: updatedBooks);
    } catch (e) {
      // Silence error if recording fails
    }
  }

  Future<BookModel?> fetchBookDetails(int id) async {
    try {
      final response = await _apiClient.dio.get('core/books/$id/');
      return BookModel.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  void addBook(BookModel book) {
    state = BookFeedState(
      status: BookFeedStatus.loaded,
      books: [book, ...state.books],
    );
  }

  Future<void> toggleLibrary(int id, WidgetRef ref) async {
    try {
      await _apiClient.dio.post('core/books/$id/toggle_library/');
      // Refresh the specific book detail provider
      ref.invalidate(currentBookProvider(id));
      // Also refresh the library tab
      ref.read(myBooksProvider.notifier).fetchMyBooks();
    } catch (e) {
      debugPrint("Failed to toggle library: $e");
    }
  }

  Future<void> deleteBook(int id) async {
    try {
      await _apiClient.dio.delete('core/books/$id/');
      // Remove from local feed
      state = state.copyWith(
        books: state.books.where((b) => b.id != id).toList(),
      );
    } catch (e) {
      debugPrint("Failed to delete book: $e");
      rethrow;
    }
  }
}

final currentBookProvider = FutureProvider.family<BookModel?, int>((ref, id) async {
  return ref.read(bookProvider.notifier).fetchBookDetails(id);
});
