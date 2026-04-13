import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../routes.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
    Timer(const Duration(seconds: 3), () {
      _navigateToNextScreen();
    });

    // Navigate to Onboarding after 3 seconds
    // Timer(const Duration(seconds: 3), () {
    //   Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
    // });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Check auth and navigate accordingly
  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    // Wait for initialization with a shorter timeout (3 seconds max)
    // initAuth should complete quickly now since it doesn't block on network
    int waitCount = 0;
    const maxWaitCount = 30; // 3 seconds max (30 * 100ms)
    while (!authService.isInitialized && waitCount < maxWaitCount) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
      if (!mounted) return;
    }

    if (!mounted) return;

    if (authService.isAuthenticated && authService.token != null) {
      // Check if email is verified
      if (!authService.isEmailVerified) {
        // Email not verified → Go to verification screen
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.emailVerify,
          arguments: {
            'email': authService.userEmail,
            'token': authService.token,
          },
        );
      } else if (!authService.isPinSet) {
        // Email verified but PIN not set → Go to PIN setup
        Navigator.of(context).pushReplacementNamed(AppRoutes.pinSetup);
      } else {
        // All verifications complete → Show app lock screen for security
        Navigator.of(context).pushReplacementNamed(AppRoutes.appLock);
      }
    } else if (authService.hasCompletedOnboarding) {
      // Returning user → Login with saved email
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.login,
        arguments: authService.savedEmail, // 👈 Reuses _user['email']
      );
    } else {
      // First-time user → Onboarding
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: AppColors.primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 0,
            children: [
              // App Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      offset: const Offset(0, 3), // soft downward shadow
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 500,
                    height: 500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // App name
              const Text(
                'Eziplug',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
