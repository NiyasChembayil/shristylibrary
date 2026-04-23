import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<dynamic>>((ref) {
  return NotificationNotifier(ref.read(apiClientProvider));
});

final unreadNotificationCountProvider = StateProvider<int>((ref) => 0);

class NotificationNotifier extends StateNotifier<List<dynamic>> {
  final ApiClient _apiClient;

  NotificationNotifier(this._apiClient) : super([]);

  Future<void> fetchNotifications() async {
    try {
      final response = await _apiClient.dio.get('social/notifications/');
      if (response.data is Map && response.data.containsKey('results')) {
        state = response.data['results'] as List<dynamic>;
      } else {
        state = response.data as List<dynamic>;
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<int> fetchUnreadCount() async {
    try {
      final response = await _apiClient.dio.get('social/notifications/unread_count/');
      return response.data['count'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  void addNotification(dynamic notification) {
    state = [notification, ...state];
  }

  Future<void> markAllRead(WidgetRef ref) async {
    try {
      await _apiClient.dio.post('social/notifications/mark_all_read/');
      await fetchNotifications();
      // Reset unread count
      ref.read(unreadNotificationCountProvider.notifier).state = 0;
    } catch (e) {
      // Handle error
    }
  }
}
