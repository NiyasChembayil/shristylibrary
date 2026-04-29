import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/book_model.dart';
import 'dart:io';

class AuthorStudioState {
  final bool isLoading;
  final List<BookModel> stories;
  final String? error;

  AuthorStudioState({
    this.isLoading = false,
    this.stories = const [],
    this.error,
  });

  AuthorStudioState copyWith({
    bool? isLoading,
    List<BookModel>? stories,
    String? error,
  }) {
    return AuthorStudioState(
      isLoading: isLoading ?? this.isLoading,
      stories: stories ?? this.stories,
      error: error ?? this.error,
    );
  }
}

final authorStudioProvider = StateNotifierProvider<AuthorStudioNotifier, AuthorStudioState>((ref) {
  return AuthorStudioNotifier(ref.read(apiClientProvider));
});

class AuthorStudioNotifier extends StateNotifier<AuthorStudioState> {
  final ApiClient _apiClient;

  AuthorStudioNotifier(this._apiClient) : super(AuthorStudioState());

  Future<void> fetchMyStories() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.dio.get('core/books/my_stories/');
      final List rawList = response.data;
      final stories = rawList.map((json) => BookModel.fromJson(json)).toList();
      state = state.copyWith(isLoading: false, stories: stories);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<BookModel?> createStory({
    required String title,
    required String category,
    String? description,
    File? coverImage,
    File? audioFile,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      FormData formData = FormData.fromMap({
        'title': title,
        'category_name': category,
        'description': description,
      });

      if (coverImage != null) {
        formData.files.add(MapEntry(
          'cover',
          await MultipartFile.fromFile(coverImage.path, filename: 'cover.jpg'),
        ));
      }

      if (audioFile != null) {
        formData.files.add(MapEntry(
          'audio_file',
          await MultipartFile.fromFile(audioFile.path, filename: 'audio.mp3'),
        ));
      }

      final response = await _apiClient.dio.post('core/books/', data: formData);
      final newStory = BookModel.fromJson(response.data);
      
      state = state.copyWith(
        isLoading: false,
        stories: [newStory, ...state.stories],
      );
      return newStory;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> updateChapter(int chapterId, String content) async {
    try {
      await _apiClient.dio.patch('core/chapters/$chapterId/', data: {
        'content': content,
      });
      return true;
    } catch (e) {
      debugPrint("Auto-save failed: $e");
      return false;
    }
  }

  Future<String?> fetchStoryBible(int bookId) async {
    try {
      final response = await _apiClient.dio.get('core/books/$bookId/bible/');
      return response.data['content'] ?? '';
    } catch (e) {
      debugPrint("Failed to fetch bible: $e");
      return null;
    }
  }

  Future<bool> updateStoryBible(int bookId, String content) async {
    try {
      await _apiClient.dio.patch('core/books/$bookId/bible/', data: {
        'content': content,
      });
      return true;
    } catch (e) {
      debugPrint("Bible save failed: $e");
      return false;
    }
  }

  Future<bool> deleteStory(int bookId) async {
    try {
      await _apiClient.dio.delete('core/books/$bookId/');
      state = state.copyWith(
        stories: state.stories.where((s) => s.id != bookId).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
