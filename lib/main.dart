import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'theme.dart';
import 'routes.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
