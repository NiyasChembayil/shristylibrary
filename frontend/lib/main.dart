import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme.dart';
import 'widgets/bottom_nav_shell.dart';
import 'features/auth/login_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/purchase_provider.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/push_notification_service.dart';
import 'core/api_client.dart';
import 'package:uni_links/uni_links.dart';
import 'dart:async';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// No longer needed: AudioHandler is managed via Riverpod provider now.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase: Skipping initialization (No config found or error): $e");
  }

  // Use a manual container to allow background initialization after runApp
  final container = ProviderContainer();

  debugPrint('Main: AudioService initialization disabled for Web testing.');
  // _initAudioService(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SrishtyApp(),
    ),
  );
}


class SrishtyApp extends ConsumerStatefulWidget {
  const SrishtyApp({super.key});

  @override
  ConsumerState<SrishtyApp> createState() => _SrishtyAppState();
}

class _SrishtyAppState extends ConsumerState<SrishtyApp> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    // Handle initial link
    try {
      final initialLink = await getInitialLink();
      if (initialLink != null) {
        _processLink(initialLink);
      }
    } catch (e) {
      debugPrint('DeepLink: Error fetching initial link: $e');
    }

    // Handle incoming links
    _sub = linkStream.listen((String? link) {
      if (link != null) _processLink(link);
    }, onError: (err) {
      debugPrint('DeepLink: Stream Error: $err');
    });
  }

  void _processLink(String link) {
    debugPrint('DeepLink: Processing link: $link');
    final uri = Uri.parse(link);
    
    // Format: srishty://preview/123
    if (uri.scheme == 'srishty' && uri.host == 'preview') {
      final bookIdStr = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (bookIdStr != null) {
        final bookId = int.tryParse(bookIdStr);
        if (bookId != null) {
          _navigateToPreview(bookId);
        }
      }
    }
  }

  void _navigateToPreview(int bookId) {
    debugPrint('DeepLink: Navigating to preview for book $bookId');
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/', // Reset to home
      (route) => false,
    );
    
    // Add small delay to ensure navigator is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => BookDetailScreen(
            id: bookId,
            title: 'Preview',
            author: '...',
            coverUrl: '',
            description: 'Loading preview...',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    
    if (authState.status == AuthStatus.authenticated) {
      ref.watch(purchaseProvider);
      ref.read(notificationServiceProvider).init();
      PushNotificationService.initialize(ref.read(apiClientProvider));
    } else {
      ref.read(notificationServiceProvider).disconnect();
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Srishty',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _getHome(authState.status),
    );
  }

  Widget _getHome(AuthStatus status) {
    switch (status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const SplashScreen();
      case AuthStatus.authenticated:
        return const BottomNavShell();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginScreen();
    }
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder/Image for logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.book, size: 50, color: Colors.blue),
            ),
            const SizedBox(height: 24),
            const Text(
              'SRISHTY',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
