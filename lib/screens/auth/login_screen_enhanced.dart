import 'dart:convert';
import 'dart:io' show InternetAddress, SocketException;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/toast_helper.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/debug_logger.dart';
import '../../routes.dart';

class LoginScreenEnhanced extends StatefulWidget {
  final String? savedEmail;

  const LoginScreenEnhanced({super.key, this.savedEmail});

  @override
  State<LoginScreenEnhanced> createState() => _LoginScreenEnhancedState();
}

class _LoginScreenEnhancedState extends State<LoginScreenEnhanced>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePassword = true;

  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late FocusNode _emailFocusNode;
  late FocusNode _passwordFocusNode;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isReturningUser = false;
  
  // Individual field errors for inline display
  String? _emailError;
  String? _passwordError;
  
  // Hidden debug access - tap title 5 times to open debug logs
  int _debugTapCount = 0;
  DateTime? _lastDebugTap;

  @override
  void initState() {
    super.initState();

    _isReturningUser = widget.savedEmail != null && widget.savedEmail!.isNotEmpty;
    _emailController = TextEditingController(text: widget.savedEmail ?? '');
    _passwordController = TextEditingController();
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _animationController.forward();

    if (_isReturningUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _passwordFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _switchUser() {
    setState(() {
      _isReturningUser = false;
      _emailController.clear();
      _passwordController.clear();
      _emailError = null;
      _passwordError = null;
    });
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email address is required';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value) && !value.contains('@')) {
      // Allow username or email
      if (value.length < 3) {
        return 'Enter a valid email or username';
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  void _validateFields() {
    setState(() {
      _emailError = _validateEmail(_emailController.text);
      _passwordError = _validatePassword(_passwordController.text);
    });
  }
  
  void _onDebugTap() {
    final now = DateTime.now();
    if (_lastDebugTap != null && now.difference(_lastDebugTap!).inSeconds > 2) {
      // Reset if more than 2 seconds between taps
      _debugTapCount = 0;
    }
    _lastDebugTap = now;
    _debugTapCount++;
    
    if (_debugTapCount >= 5) {
      _debugTapCount = 0;
      Navigator.pushNamed(context, AppRoutes.debugLogs);
    }
  }

  /// Check if device has internet connectivity
  Future<bool> _hasInternetConnection() async {
    // On web, skip this check - CORS blocks requests to external sites
    // If the app loaded, the user has internet
    if (kIsWeb) return true;
    
    try {
      // Use dart:io for native platforms (Android/iOS)
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  void _login() async {
    _validateFields();
    
    if (_emailError != null || _passwordError != null) {
      return;
    }

    setState(() => _loading = true);
    
    // Check internet connectivity first
    final hasInternet = await _hasInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        setState(() => _loading = false);
        ToastHelper.showError("No internet connection");
      }
      return;
    }
    
    final auth = Provider.of<AuthService>(context, listen: false);

    final data = {
      "email": _emailController.text.trim(),
      "password": _passwordController.text.trim(),
    };

    Map<String, dynamic>? result;
    
    try {
      result = await auth.login(data);
    } catch (e, stackTrace) {
      debugPrint('Login exception: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _loading = false);
        // Use sanitized error message for production
        ToastHelper.showException(e, fallback: "Network error. Please try again.");
      }
      return;
    }
    
    if (!mounted) return;
    setState(() => _loading = false);
    
    if (result == null) {
      ToastHelper.showError("No response from server");
      return;
    }

    try {
      if (result['success'] == true) {
        // Check verification status
        final isEmailVerified = result['isEmailVerified'] as bool? ?? true;
        final isLivenessComplete = result['isLivenessComplete'] as bool? ?? false;
        final isPinSet = result['isPinSet'] as bool? ?? false;
        
        await debugLogger.log('LOGIN', 'Success! isEmailVerified: $isEmailVerified, isLivenessComplete: $isLivenessComplete, isPinSet: $isPinSet');
        
        if (!isEmailVerified) {
          // Email not verified - redirect to verification screen
          await debugLogger.log('NAV', 'Navigating to email verify screen');
          ToastHelper.showInfo(result['message'] ?? "Please verify your email to continue");
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.emailVerify,
              arguments: {
                'email': _emailController.text.trim(),
                'token': result['token'] ?? '',
              },
            );
          }
        } else if (!isPinSet) {
          // Liveness check is now part of KYC Tier 2, so we skip it here
          await debugLogger.log('NAV', 'Navigating to PIN setup screen');
          ToastHelper.showInfo("Please set up your PIN");
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.pinSetup);
          }
        } else if (!isPinSet) {
          // Liveness complete but PIN not set
          await debugLogger.log('NAV', 'Navigating to PIN setup screen');
          ToastHelper.showInfo("Please set up your PIN");
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.pinSetup);
          }
        } else {
          // All verifications complete - proceed to main screen
          await debugLogger.log('NAV', 'Navigating to main screen...');
          ToastHelper.showSuccess(result['message'] ?? "Login successful");
          if (mounted) {
            await debugLogger.log('NAV', 'Calling pushReplacementNamed to: ${AppRoutes.main}');
            Navigator.pushReplacementNamed(context, AppRoutes.main);
            await debugLogger.log('NAV', 'Navigation called successfully');
          } else {
            await debugLogger.log('NAV', 'Widget not mounted, skipping navigation');
          }
        }
      } else {
        final statusCode = result['statusCode'] as int?;
        if (statusCode != null && statusCode >= 500) {
          ToastHelper.showError('Network error. Please try again later.');
        } else {
          // Show field-specific errors if available
          final errors = result['errors'] as Map<String, dynamic>?;
          if (errors != null) {
            setState(() {
              _emailError = errors['email']?.toString();
              _passwordError = errors['password']?.toString();
            });
          }
          ToastHelper.showError(result['message'] ?? "Invalid credentials");
        }
      }
    } catch (e, stackTrace) {
      await debugLogger.log('ERROR', 'Post-login processing error: $e');
      // Use sanitized error message
      ToastHelper.showException(e, fallback: "Something went wrong. Please try again.");
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? errorText,
    bool obscureText = false,
    bool readOnly = false,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    Function(String)? onChanged,
    Function(String)? onFieldSubmitted,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: hasError ? Colors.red.shade700 : AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: hasError 
                    ? Colors.red.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            readOnly: readOnly,
            keyboardType: keyboardType,
            onChanged: onChanged,
            onFieldSubmitted: onFieldSubmitted,
            style: TextStyle(
              fontSize: 16,
              color: readOnly ? Colors.grey.shade600 : AppColors.text,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(
                  icon,
                  color: hasError ? Colors.red.shade400 : AppColors.primary.withOpacity(0.7),
                  size: 22,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 50),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? Colors.red.shade300 : Colors.grey.shade200,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : AppColors.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
          ),
        ),
        // Inline error message
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: Colors.red.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  errorText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: AppColors.primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header with gradient
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, sh * 0.05, 24, 40),
                  child: Column(
                    children: [
                      // Logo - Long press to open debug logs
                      GestureDetector(
                        onLongPress: () {
                          Navigator.pushNamed(context, AppRoutes.debugLogs);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 60,
                            width: 60,
                            color: Colors.white,
                            colorBlendMode: BlendMode.srcIn,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.bolt,
                                size: 50,
                                color: Colors.white,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      if (_isReturningUser) ...[
                        // Returning user avatar
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(
                              _emailController.text.isNotEmpty
                                  ? _emailController.text[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _onDebugTap,
                          child: const Text(
                            'Welcome Back!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _emailController.text,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ] else ...[
                        GestureDetector(
                          onTap: _onDebugTap,
                          child: const Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue to your account',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Form Section
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),

                          // Email Field
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            hint: 'Enter your email or username',
                            icon: Icons.email_outlined,
                            errorText: _emailError,
                            readOnly: _isReturningUser,
                            focusNode: _emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) {
                              if (_emailError != null) {
                                setState(() => _emailError = _validateEmail(value));
                              }
                            },
                            suffixIcon: _isReturningUser
                                ? IconButton(
                                    icon: Icon(Icons.edit_outlined, color: AppColors.primary),
                                    onPressed: _switchUser,
                                  )
                                : null,
                          ),

                          if (_isReturningUser) ...[
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _switchUser,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 30),
                                ),
                                child: Text(
                                  'Not you? Switch account',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          SizedBox(height: _isReturningUser ? 16 : 24),

                          // Password Field
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'Enter your password',
                            icon: Icons.lock_outline,
                            errorText: _passwordError,
                            obscureText: _obscurePassword,
                            focusNode: _passwordFocusNode,
                            onChanged: (value) {
                              if (_passwordError != null) {
                                setState(() => _passwordError = _validatePassword(value));
                              }
                            },
                            onFieldSubmitted: (_) => _login(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey.shade500,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.forgotPassword);
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 30),
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Login Button
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withOpacity(0.85),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Sign In',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Divider with "or"
                          if (!_isReturningUser) ...[
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey.shade300)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'or',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.grey.shade300)),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Register Link
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(context, AppRoutes.register);
                                    },
                                    child: Text(
                                      'Register',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
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
