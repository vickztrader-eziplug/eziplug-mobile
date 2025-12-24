import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'theme.dart';
import 'routes.dart';
import 'screens/splash/splash_screen.dart';

// void main() {
//   runApp(const MyApp());
// }
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();
  await authService.initAuth();
  // await authService.checkAuth();

  runApp(
    ChangeNotifierProvider<AuthService>.value(
      value: authService,
      child: MyApp(),
    ),
  );
  // runApp(
  //   ChangeNotifierProvider(create: (_) => AuthService(), child: const MyApp()),
  // );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'Eziplug',
            theme: AppTheme.light(),
            debugShowCheckedModeBanner: false,
            onGenerateRoute: AppRoutes.generateRoute,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
