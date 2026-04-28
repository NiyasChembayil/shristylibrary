import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider((ref) => ApiClient());

// ⚠️ BEFORE RELEASING TO PLAY STORE:
// Replace the baseUrl below with your actual deployed backend URL.
// Example: 'https://api.srishty.com/api/'
// Using localhost (127.0.0.1) will NOT work on real devices!
// Using localhost (127.0.0.1) will NOT work on real physical devices or Android emulators!
String get _baseUrl {
  // 🚀 PRODUCTION (Default)
  return 'https://srishty-backend.onrender.com/api/';
  
  // 🏠 LOCAL DEVELOPMENT
  // For physical devices, use your machine's IP (e.g., 'http://192.168.1.23:8000/api/')
  // For Android Emulator, use 'http://10.0.2.2:8000/api/'
  // return 'http://192.168.1.23:8000/api/'; 
}

class ApiClient {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  ApiClient() {
    // Only log requests in debug mode — never in production builds
    if (kDebugMode) {
      dio.interceptors
          .add(LogInterceptor(responseBody: true, requestBody: true));
    }

    // Add interceptor to handle 401 Unauthorized (Expired Tokens)
    dio.interceptors.add(InterceptorsWrapper(
      onError: (e, handler) {
        if (e.response?.statusCode == 401) {
          // If token is expired, clear it so we can at least browse as a guest
          clearAuthToken();
          debugPrint("Auth: Token expired/invalid (401). Cleared headers.");
        } else if (e.response?.statusCode == 500) {
          debugPrint(
              "⚠️ SERVER ERROR (500): The backend crashed. Check Render logs.");
          debugPrint("URL: ${e.requestOptions.uri}");
          debugPrint("Response: ${e.response?.data}");
        } else {
          debugPrint("🌐 API ERROR [${e.response?.statusCode}]: ${e.message}");
          debugPrint("URL: ${e.requestOptions.uri}");
        }
        return handler.next(e);
      },
    ));
  }

  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    dio.options.headers.remove('Authorization');
  }
}
