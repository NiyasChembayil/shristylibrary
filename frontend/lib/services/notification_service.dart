import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/post_provider.dart';

final notificationServiceProvider = Provider((ref) => NotificationService(ref));

class NotificationService {
  final Ref _ref;
  WebSocketChannel? _channel;

  NotificationService(this._ref);

  void init() {
    final token = _ref.read(authProvider).token;
    if (token == null) return;

    // Route WebSocket traffic to the live production server using secure WSS
    final wsUrl = 'wss://srishty-backend.onrender.com/ws/notifications/';
    
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl?token=$token'),
      );

      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['type'] == 'notification') {
            _ref.read(notificationProvider.notifier).addNotification(data['notification']);
          } else if (data['type'] == 'social_update') {
            final postData = data['data'];
            _ref.read(postFeedProvider.notifier).updatePostActivity(
              postData['post_id'],
              postData['likes_count'],
              postData['comments_count'],
            );
          }
        },
        onError: (error) {
          // Add connection error logging here if needed in future
        },
        onDone: () {
          // Add disconnect logic here if needed in future
        },
      );
    } catch (e) {
      // Add connection failed fallback logic here if needed in future
    }
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
