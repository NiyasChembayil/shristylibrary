import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import 'auth_provider.dart';

final socialProvider = StateNotifierProvider<SocialFollowNotifier, Map<String, bool>>((ref) {
  return SocialFollowNotifier(ref);
});

class SocialFollowNotifier extends StateNotifier<Map<String, bool>> {
  final Ref _ref;
  final ApiClient _apiClient;

  SocialFollowNotifier(this._ref) 
      : _apiClient = _ref.read(apiClientProvider),
        super({});

  void setFollowingStatus(String username, bool isFollowing) {
    state = {...state, username: isFollowing};
  }

  Future<void> toggleFollow(String username, int profileId) async {
    try {
      final response = await _apiClient.dio.post('accounts/profile/$profileId/follow/');
      final status = response.data['status'];
      
      final isNowFollowing = status == 'followed';
      state = {...state, username: isNowFollowing};
      
      // Update global auth state if needed
      if (isNowFollowing) {
        _ref.read(authProvider.notifier).updateFollowingCount(1);
      } else {
        _ref.read(authProvider.notifier).updateFollowingCount(-1);
      }
    } catch (e) {
      // Handle error locally or through state of another provider if needed
    }
  }
}
