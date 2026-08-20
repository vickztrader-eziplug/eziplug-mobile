import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/debug_logger.dart';
import 'services/api_client.dart';
import 'theme.dart';
import 'routes.dart';
import 'providers/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Test network connectivity immediately on startup (skip on web for now)
  if (!kIsWeb) {
    await _testNetworkConnectivity();
  } else {
    await debugLogger.log('STARTUP', 'App starting on WEB platform');
  }
  
  // Initialize Firebase
  // On iOS, FirebaseApp.configure() is called in AppDelegate.swift first.
  // Calling Firebase.initializeApp() in Dart is still required — it links
  // the Flutter plugin to the already-configured native instance (no conflict).
  try {
    await Firebase.initializeApp();
    // Register the background message handler IMMEDIATELY after Firebase init.
    // This must happen before any other Firebase Messaging calls.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  
  final authService = AuthService();
  final pushService = PushNotificationService(authService);
  
  // Initialize Push Notifications (with timeout to prevent blocking the app)
  try {
    await pushService.initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('Push service initialization timed out, continuing...');
      },
    );
  } catch (e) {
    debugPrint('Push service initialization error: $e');
  }
  
  // Initialize auth with a timeout to prevent blocking the app
  try {
    await authService.initAuth().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        // If initialization takes too long, continue anyway
        // The splash screen will handle re-checking
        debugPrint('Auth initialization timed out, continuing...');
      },
    );
  } catch (e) {
    debugPrint('Auth initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// Test network connectivity at startup to help debug release build issues
/// Only runs on mobile/desktop platforms (not web)
Future<void> _testNetworkConnectivity() async {
  final isRelease = kReleaseMode;
  await debugLogger.log('STARTUP', 'App starting in ${isRelease ? "RELEASE" : "DEBUG"} mode');
  
  try {
    // Test HTTP request using the API client
    await debugLogger.log('NET_TEST', 'Testing HTTPS connection...');
    final response = await apiClient.get(
      Uri.parse('https://app.eziplug.app/api'),
      headers: {'Accept': 'application/json'},
      timeout: const Duration(seconds: 15),
    );
    await debugLogger.log('NET_TEST', 'HTTPS status: ${response.statusCode}');
  } catch (e) {
    await debugLogger.log('NET_ERROR', 'Network test failed: ${e.runtimeType}: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Eziplug',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          onGenerateRoute: AppRoutes.generateRoute,
          initialRoute: AppRoutes.splash,
        );
      },
    );
  }
}
