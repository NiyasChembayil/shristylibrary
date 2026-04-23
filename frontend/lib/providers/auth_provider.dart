import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_model.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? token;
  final String? errorMessage;
  final ProfileModel? profile;

  AuthState({required this.status, this.token, this.errorMessage, this.profile});
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(AuthState(status: AuthStatus.initial)) {
    _checkToken();
  }

  Future<void> _checkToken() async {
    try {
      debugPrint('Auth: Checking token...');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null) {
        debugPrint('Auth: Token found, fetching profile...');
        _apiClient.setAuthToken(token);
        final profile = await _fetchProfile();
        state = AuthState(status: AuthStatus.authenticated, token: token, profile: profile);
        debugPrint('Auth: Authenticated.');
      } else {
        debugPrint('Auth: No token found.');
        state = AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      debugPrint('Auth: Initialization error: $e');
      state = AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> refreshProfile() async {
    final profile = await _fetchProfile();
    if (profile != null) {
      state = AuthState(status: AuthStatus.authenticated, token: state.token, profile: profile);
    }
  }

  Future<ProfileModel?> _fetchProfile() async {
    try {
      final response = await _apiClient.dio.get('accounts/profile/me/');
      // The serializer now returns username, role, bio, avatar, followers_count
      return ProfileModel.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<void> login(String username, String password) async {
    state = AuthState(status: AuthStatus.loading);
    try {
      final response = await _apiClient.dio.post('token/', data: {
        'username': username,
        'password': password,
      });
      final token = response.data['access'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      _apiClient.setAuthToken(token);
      
      final profile = await _fetchProfile();
      state = AuthState(status: AuthStatus.authenticated, token: token, profile: profile);
    } catch (e) {
      String message = 'Login failed. Please check your credentials.';
      
      // Better error detection
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout || 
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          message = 'Server unreachable. Check if current IP in api_client.dart matches your computer\'s IP.';
        } else if (e.response?.statusCode == 401) {
          message = 'Invalid username or password.';
        } else if (e.response?.data is Map) {
          final data = e.response?.data as Map;
          if (data.containsKey('detail')) {
            message = data['detail'];
          }
        }
      }
      
      state = AuthState(status: AuthStatus.error, errorMessage: message);
    }
  }

  Future<bool> register(String username, String email, String password, String role) async {
    state = AuthState(status: AuthStatus.loading);
    try {
      await _apiClient.dio.post('accounts/auth/register/', data: {
        'username': username,
        'email': email,
        'password': password,
        'role': role,
      });
      state = AuthState(status: AuthStatus.unauthenticated);
      return true;
    } catch (e) {
      // Try to extract the server's validation error message
      String message = 'Registration failed. Please try again.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map) {
          final firstKey = data.keys.first;
          final firstVal = data[firstKey];
          message = firstVal is List ? firstVal.first.toString() : firstVal.toString();
        }
      } catch (_) {}
      state = AuthState(status: AuthStatus.error, errorMessage: message);
      return false;
    }
  }

  Future<bool> updateProfile({String? bio, String? avatar}) async {
    try {
      final Map<String, dynamic> data = {
        'bio': bio,
        'avatar': avatar,
      }..removeWhere((key, value) => value == null);
      final response = await _apiClient.dio.patch('accounts/profile/me/', data: data);
      final updatedProfile = ProfileModel.fromJson(response.data);
      state = AuthState(
        status: AuthStatus.authenticated,
        token: state.token,
        profile: updatedProfile,
      );
      return true;
    } catch (e) {
      debugPrint('Auth: Update profile error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> updateAccount(String key, String value) async {
    try {
      final Map<String, dynamic> data = {key: value};
      final response = await _apiClient.dio.patch('accounts/profile/me/', data: data);
      final updatedProfile = ProfileModel.fromJson(response.data);
      state = AuthState(
        status: AuthStatus.authenticated,
        token: state.token,
        profile: updatedProfile,
      );
      return {'success': true};
    } catch (e) {
      debugPrint('Auth: Update account error: $e');
      String message = 'Failed to update $key.';
      if (e is DioException && e.response?.data is Map) {
        final errorData = e.response?.data as Map;
        // Check for nested user errors (e.g., {'user': {'username': ['...']}})
        if (errorData.containsKey('user') && errorData['user'] is Map) {
          final userErrors = errorData['user'] as Map;
          if (userErrors.containsKey(key)) {
            message = (userErrors[key] as List).first.toString();
          }
        } else if (errorData.containsKey(key)) {
          message = (errorData[key] as List).first.toString();
        }
      }
      return {'success': false, 'message': message};
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    _apiClient.clearAuthToken();
    state = AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> upgradeToAuthor() async {
    try {
      final response = await _apiClient.dio.post('accounts/profile/upgrade_role/');
      if (response.data['status'] == 'success' || response.data['status'] == 'already_author') {
        final profile = await _fetchProfile();
        state = AuthState(status: AuthStatus.authenticated, token: state.token, profile: profile);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Auth: Upgrade to author error: $e');
      return false;
    }
  }

  /// Manually update the current user's profile statistics (following, followers etc.)
  void updateFollowingCount(int delta) {
    if (state.profile == null) return;
    
    final currentProfile = state.profile!;
    final newProfile = ProfileModel(
      id: currentProfile.id,
      username: currentProfile.username,
      role: currentProfile.role,
      bio: currentProfile.bio,
      avatar: currentProfile.avatar,
      followersCount: currentProfile.followersCount,
      followingCount: currentProfile.followingCount + delta,
      userId: currentProfile.userId,
      email: currentProfile.email,
    );
    
    state = AuthState(
      status: state.status,
      token: state.token,
      profile: newProfile,
      errorMessage: state.errorMessage,
    );
  }
}
