// lib/screens/security/app_lock_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:cashpoint/core/theme/app_colors.dart';
import 'package:cashpoint/services/biometric_service.dart';
import 'package:cashpoint/services/auth_service.dart';
import 'package:cashpoint/routes.dart';

/// Screen shown when the user needs to authenticate to access the app.
/// Supports:
/// - Fingerprint/Face ID authentication
/// - Fallback to transaction PIN after 3 failed attempts
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  final int _pinLength = 4;
  bool _isLoading = false;
  bool _showPinInput = false;
  bool _hasError = false;
  String? _errorMessage;
  int _pinAttempts = 0;
  static const int _maxPinAttempts = 5;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeController);

    // Initialize biometric service and attempt authentication
    _initBiometric();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _initBiometric() async {
    await biometricService.init();
    
    if (biometricService.isAvailable && !biometricService.shouldFallbackToPin) {
      // Attempt biometric authentication
      _attemptBiometric();
    } else {
      // Show PIN input directly if biometric not available or too many failed attempts
      setState(() => _showPinInput = true);
    }
  }

  Future<void> _attemptBiometric() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    final result = await biometricService.authenticate(
      reason: 'Authenticate to access Eziplug',
    );

    setState(() => _isLoading = false);

    if (result.success) {
      _onAuthenticationSuccess();
    } else {
      if (result.shouldFallbackToPin) {
        setState(() {
          _showPinInput = true;
          _errorMessage = result.error;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = result.error;
        });
      }
    }
  }

  void _onNumberTap(String number) {
    HapticFeedback.lightImpact();
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += number;
        _hasError = false;
        _errorMessage = null;
      });

      if (_pin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _hasError = false;
        _errorMessage = null;
      });
    }
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _pin = '';
      _hasError = false;
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;

    if (token == null) {
      // Token is null, user needs to re-login
      _handleSessionExpired();
      return;
    }

    final result = await biometricService.verifyPin(_pin, token);

    setState(() => _isLoading = false);

    if (result.success) {
      _onAuthenticationSuccess();
    } else {
      _pinAttempts++;
      _shakeController.forward().then((_) => _shakeController.reset());
      
      if (result.sessionExpired) {
        _handleSessionExpired();
      } else if (_pinAttempts >= _maxPinAttempts) {
        // Too many failed PIN attempts - force logout
        _handleTooManyFailedAttempts();
      } else {
        setState(() {
          _pin = '';
          _hasError = true;
          _errorMessage = '${result.message} (${_maxPinAttempts - _pinAttempts} attempts remaining)';
        });
      }
    }
  }

  void _onAuthenticationSuccess() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.main);
  }

  void _handleSessionExpired() {
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.logout();
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  void _handleTooManyFailedAttempts() {
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.logout();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Too many failed attempts. Please login again.'),
        backgroundColor: AppColors.error,
      ),
    );
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  Widget _buildPinIndicator(int index) {
    final isFilled = index < _pin.length;
    final isActive = index == _pin.length;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
              _hasError ? _shakeAnimation.value * (index.isEven ? 1 : -1) : 0,
              0),
          child: child,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 56,
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isFilled
              ? (_hasError
                  ? Colors.red.shade50
                  : AppColors.primary.withOpacity(0.1))
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hasError
                ? Colors.red
                : isFilled
                    ? AppColors.primary
                    : isActive
                        ? AppColors.primary.withOpacity(0.5)
                        : Colors.grey.shade300,
            width: isActive ? 2 : 1.5,
          ),
          boxShadow: isFilled
              ? [
                  BoxShadow(
                    color: (_hasError ? Colors.red : AppColors.primary)
                        .withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedScale(
            scale: isFilled ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _hasError ? Colors.red : AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number,
      {IconData? icon, Color? iconColor}) {
    final isBackspace = icon == Icons.backspace_outlined;
    final isEmpty = number.isEmpty && icon == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: isEmpty
            ? null
            : () {
                if (icon == Icons.backspace_outlined) {
                  _onBackspace();
                } else if (number.isNotEmpty) {
                  _onNumberTap(number);
                }
              },
        onLongPress: isBackspace ? _onClear : null,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isEmpty ? Colors.transparent : Colors.grey.shade100,
          ),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: 28,
                    color: iconColor ?? AppColors.textColor,
                  )
                : Text(
                    number,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Spacer(flex: 1),
              
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 60,
                    height: 60,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                _showPinInput ? 'Enter Your PIN' : 'Welcome Back',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                _showPinInput
                    ? 'Enter your 4-digit transaction PIN to continue'
                    : 'Use ${biometricService.biometricTypeName} to unlock',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              if (_showPinInput) ...[
                // PIN indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pinLength,
                    (index) => _buildPinIndicator(index),
                  ),
                ),
                
                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: _hasError ? Colors.red : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                
                const Spacer(flex: 1),
                
                // Number pad
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumberButton('1'),
                          _buildNumberButton('2'),
                          _buildNumberButton('3'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumberButton('4'),
                          _buildNumberButton('5'),
                          _buildNumberButton('6'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumberButton('7'),
                          _buildNumberButton('8'),
                          _buildNumberButton('9'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumberButton('', icon: null), // Empty spacer
                          _buildNumberButton('0'),
                          _buildNumberButton('',
                              icon: Icons.backspace_outlined,
                              iconColor: AppColors.textSecondary),
                        ],
                      ),
                    ],
                  ),
                
                const SizedBox(height: 24),
                
                // Try biometric again button (if available)
                if (biometricService.isAvailable &&
                    !biometricService.shouldFallbackToPin)
                  TextButton.icon(
                    onPressed: _attemptBiometric,
                    icon: Icon(
                      biometricService.availableBiometrics
                              .contains(BiometricType.face)
                          ? Icons.face
                          : Icons.fingerprint,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'Use ${biometricService.biometricTypeName} instead',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ),
              ] else ...[
                // Biometric prompt
                const Spacer(flex: 1),
                
                if (_isLoading)
                  Column(
                    children: [
                      const CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Authenticating...',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      // Fingerprint icon
                      GestureDetector(
                        onTap: _attemptBiometric,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _hasError
                                ? Colors.red.withOpacity(0.1)
                                : AppColors.primary.withOpacity(0.1),
                            border: Border.all(
                              color: _hasError ? Colors.red : AppColors.primary,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            biometricService.availableBiometrics
                                    .contains(BiometricType.face)
                                ? Icons.face
                                : Icons.fingerprint,
                            size: 48,
                            color:
                                _hasError ? Colors.red : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                _hasError ? Colors.red : AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      TextButton(
                        onPressed: _attemptBiometric,
                        child: const Text(
                          'Tap to authenticate',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                
                const Spacer(flex: 2),
                
                // Use PIN option
                TextButton(
                  onPressed: () => setState(() => _showPinInput = true),
                  child: const Text(
                    'Use PIN instead',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}
