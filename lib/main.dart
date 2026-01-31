import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/debug_logger.dart';
import 'services/api_client.dart';
import 'theme.dart';
import 'routes.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Test network connectivity immediately on startup
  await _testNetworkConnectivity();
  
  final authService = AuthService();
  
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
    ChangeNotifierProvider<AuthService>.value(
      value: authService,
      child: const MyApp(),
    ),
  );
}

/// Test network connectivity at startup to help debug release build issues
Future<void> _testNetworkConnectivity() async {
  final isRelease = kReleaseMode;
  await debugLogger.log('STARTUP', 'App starting in ${isRelease ? "RELEASE" : "DEBUG"} mode');
  
  try {
    // Test 1: DNS resolution
    await debugLogger.log('NET_TEST', 'Testing DNS resolution...');
    final addresses = await InternetAddress.lookup('app.eziplug.app')
        .timeout(const Duration(seconds: 10));
    await debugLogger.log('NET_TEST', 'DNS resolved: ${addresses.first.address}');
    
    // Test 2: HTTP request using the robust API client
    await debugLogger.log('NET_TEST', 'Testing HTTPS connection...');
    final response = await apiClient.get(
      Uri.parse('https://app.eziplug.app/api'),
      headers: {'Accept': 'application/json'},
      timeout: const Duration(seconds: 15),
    );
    await debugLogger.log('NET_TEST', 'HTTPS status: ${response.statusCode}');
  } on SocketException catch (e) {
    await debugLogger.log('NET_ERROR', 'Socket error: $e');
  } on HandshakeException catch (e) {
    await debugLogger.log('NET_ERROR', 'SSL Handshake error: $e');
  } catch (e) {
    await debugLogger.log('NET_ERROR', 'Network test failed: ${e.runtimeType}: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eziplug',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRoutes.generateRoute,
      home: const SplashScreen(),
    );
  }
}
