import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> initialize(ApiClient apiClient) async {
    try {
      // 1. Request permission (iOS/Web)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
      }

      // 2. Get token and send to backend
      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _sendTokenToBackend(apiClient, token);
      }

      // 3. Listen for token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        _sendTokenToBackend(apiClient, newToken);
      });

      // 4. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification?.title}');
          // In a real app, you might show a local notification here
        }
      });
      
    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  }

  static Future<void> _sendTokenToBackend(ApiClient apiClient, String token) async {
    try {
      await apiClient.dio.post('accounts/profile/update_fcm_token/', data: {'token': token});
      debugPrint('FCM token sent to backend successfully');
    } catch (e) {
      debugPrint('Error sending FCM token to backend: $e');
    }
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}
