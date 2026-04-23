import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/book_model.dart';

import 'package:flutter/foundation.dart';

class MyBooksState {
  final List<BookModel> books;
  final bool isLoading;
  final String? error;

  MyBooksState({
    required this.books,
    this.isLoading = false,
    this.error,
  });

  factory MyBooksState.initial() => MyBooksState(books: []);
}

final myBooksProvider = StateNotifierProvider<MyBooksNotifier, MyBooksState>((ref) {
  return MyBooksNotifier(ref.read(apiClientProvider));
});

class MyBooksNotifier extends StateNotifier<MyBooksState> {
  final ApiClient _apiClient;

  MyBooksNotifier(this._apiClient) : super(MyBooksState.initial()) {
    fetchMyBooks();
  }

  Future<void> fetchMyBooks() async {
    state = MyBooksState(books: state.books, isLoading: true);
    try {
      final response = await _apiClient.dio.get('core/books/my_library/');
      final List data = response.data is List ? response.data : (response.data['results'] ?? []);
      
      final books = data.map((json) => BookModel.fromJson(json)).toList();
      state = MyBooksState(books: books, isLoading: false);
    } catch (e) {
      debugPrint("Failed to fetch my books: $e");
      state = MyBooksState(books: state.books, isLoading: false, error: e.toString());
    }
  }
}
