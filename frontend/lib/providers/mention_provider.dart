import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

// ── Data Models ──────────────────────────────────────────────────────────────

class MentionUser {
  final int id;
  final String username;
  final String? avatar;
  const MentionUser({required this.id, required this.username, this.avatar});

  factory MentionUser.fromJson(Map<String, dynamic> j) =>
      MentionUser(id: j['id'], username: j['username'], avatar: j['avatar']);
}

class MentionBook {
  final int id;
  final String title;
  final String? slug;
  final String? cover;
  const MentionBook(
      {required this.id, required this.title, this.slug, this.cover});

  factory MentionBook.fromJson(Map<String, dynamic> j) =>
      MentionBook(id: j['id'], title: j['title'], slug: j['slug'], cover: j['cover']);
}

// ── State ─────────────────────────────────────────────────────────────────────

class MentionState {
  final List<MentionUser> users;
  final List<MentionBook> books;
  final bool isLoading;
  final bool isVisible;
  final String query;

  const MentionState({
    this.users = const [],
    this.books = const [],
    this.isLoading = false,
    this.isVisible = false,
    this.query = '',
  });

  bool get hasResults => users.isNotEmpty || books.isNotEmpty;

  MentionState copyWith({
    List<MentionUser>? users,
    List<MentionBook>? books,
    bool? isLoading,
    bool? isVisible,
    String? query,
  }) =>
      MentionState(
        users: users ?? this.users,
        books: books ?? this.books,
        isLoading: isLoading ?? this.isLoading,
        isVisible: isVisible ?? this.isVisible,
        query: query ?? this.query,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final mentionProvider =
    StateNotifierProvider<MentionNotifier, MentionState>((ref) {
  return MentionNotifier(ref.read(apiClientProvider));
});

class MentionNotifier extends StateNotifier<MentionState> {
  final ApiClient _api;
  Timer? _debounce;

  MentionNotifier(this._api) : super(const MentionState());

  /// Called whenever '@' is detected in the text field.
  void search(String query) {
    _debounce?.cancel();
    if (query.isEmpty) {
      hide();
      return;
    }

    state = state.copyWith(isVisible: true, isLoading: true, query: query);

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final response =
            await _api.dio.get('social/mention-search/?q=$query');
        final data = response.data as Map<String, dynamic>;
        final users = (data['users'] as List)
            .map((j) => MentionUser.fromJson(j))
            .toList();
        final books = (data['books'] as List)
            .map((j) => MentionBook.fromJson(j))
            .toList();
        if (mounted) {
          state = state.copyWith(
            users: users,
            books: books,
            isLoading: false,
          );
        }
      } catch (_) {
        if (mounted) {
          state = state.copyWith(isLoading: false);
        }
      }
    });
  }

  /// Dismiss the mention overlay.
  void hide() {
    _debounce?.cancel();
    state = const MentionState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
