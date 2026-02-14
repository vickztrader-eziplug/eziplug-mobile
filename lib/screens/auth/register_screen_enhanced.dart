import 'package:cashpoint/screens/auth/verification_screen_enhanced.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_response.dart';
import '../../routes.dart';

class RegisterScreenEnhanced extends StatefulWidget {
  const RegisterScreenEnhanced({super.key});

  @override
  State<RegisterScreenEnhanced> createState() => _RegisterScreenEnhancedState();
}

class _RegisterScreenEnhancedState extends State<RegisterScreenEnhanced>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePassword = true;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralCodeController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Individual field errors for inline display
  Map<String, String?> _fieldErrors = {
    'first_name': null,
    'last_name': null,
    'username': null,
    'email': null,
    'phone': null,
    'password': null,
    'referral_code': null,
  };

  @override
  void initState() {
    super.initState();

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
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _referralCodeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Validation functions
  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 11) {
      return 'Phone number must be exactly 11 digits';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
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

  void _validateAllFields() {
    setState(() {
      _fieldErrors = {
        'first_name': _validateRequired(_firstNameController.text, 'First name'),
        'last_name': _validateRequired(_lastNameController.text, 'Last name'),
        'username': _validateUsername(_usernameController.text),
        'email': _validateEmail(_emailController.text),
        'phone': _validatePhone(_phoneController.text),
        'password': _validatePassword(_passwordController.text),
      };
    });
  }

  bool _hasErrors() {
    return _fieldErrors.values.any((error) => error != null);
  }

  Future<void> _register() async {
    _validateAllFields();

    if (_hasErrors()) {
      // Scroll to first error or just show the errors
      ToastHelper.showError('Please fix the errors below');
      return;
    }

    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);

    final data = {
      "first_name": _firstNameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
      "middle_name": _middleNameController.text.trim(),
      "username": _usernameController.text.trim(),
      "email": _emailController.text.trim(),
      "phone": _phoneController.text.trim(),
      "password": _passwordController.text.trim(),
      if (_referralCodeController.text.trim().isNotEmpty)
        "referral_code": _referralCodeController.text.trim(),
    };

    try {
      final result = await auth.register(data);

      if (!mounted) return;
      setState(() => _loading = false);

      // Check for validation errors from server
      if (result['errors'] != null) {
        final serverErrors = result['errors'] as Map<String, dynamic>;
        setState(() {
          serverErrors.forEach((key, value) {
            if (_fieldErrors.containsKey(key)) {
              _fieldErrors[key] = value is List ? value.first.toString() : value.toString();
            }
          });
        });
        ToastHelper.showError(result['message'] ?? 'Please fix the errors below');
        return;
      }

      if (isSuccessResponse(result)) {
        final responseData = getResponseData(result);
        final token = responseData['token'] ?? result['token'] ?? '';
        final email = _emailController.text.trim();

        ToastHelper.showSuccess(
          getResponseMessage(result).isNotEmpty
              ? getResponseMessage(result)
              : "Registration successful! Please verify your email.",
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => VerificationScreenEnhanced(
              email: email,
              token: token,
              isEmailVerification: false,
            ),
          ),
        );
      } else {
        // Check for field-specific errors
        final errors = result['errors'] as Map<String, dynamic>?;
        if (errors != null) {
          setState(() {
            errors.forEach((key, value) {
              if (_fieldErrors.containsKey(key)) {
                _fieldErrors[key] = value is List ? value.first.toString() : value.toString();
              }
            });
          });
        }
        ToastHelper.showError(
          getResponseMessage(result).isNotEmpty
              ? getResponseMessage(result)
              : "Registration failed.",
        );
      }
    } catch (e) {
      debugPrint('Registration UI error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      if (e.toString().contains('TimeoutException')) {
        ToastHelper.showError("Request timed out. Please check your internet connection.");
      } else {
        // Use sanitized error message for production
        ToastHelper.showException(e, fallback: "Network error. Please try again.");
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String errorKey,
    bool obscureText = false,
    bool isOptional = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
    Function(String)? onChanged,
  }) {
    final errorText = _fieldErrors[errorKey];
    final hasError = errorText != null && errorText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: hasError ? Colors.red.shade700 : AppColors.text,
              ),
            ),
            if (isOptional)
              Text(
                ' (optional)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: hasError
                    ? Colors.red.withOpacity(0.08)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            style: TextStyle(fontSize: 15, color: AppColors.text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(
                  icon,
                  color: hasError ? Colors.red.shade400 : AppColors.primary.withOpacity(0.7),
                  size: 20,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 48),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            ),
          ),
        ),
        // Inline error message with animation
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
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
                )
              : const SizedBox.shrink(),
        ),
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
                  padding: EdgeInsets.fromLTRB(24, sh * 0.04, 24, 35),
                  child: Column(
                    children: [
                      // Back button row
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 50,
                          width: 50,
                          color: Colors.white,
                          colorBlendMode: BlendMode.srcIn,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.bolt,
                              size: 40,
                              color: Colors.white,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fill in your details to get started',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
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
                          // Progress indicator
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'All fields marked are required',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),

                          // Name Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _firstNameController,
                                  label: 'First Name',
                                  hint: 'John',
                                  icon: Icons.person_outline,
                                  errorKey: 'first_name',
                                  onChanged: (value) {
                                    if (_fieldErrors['first_name'] != null) {
                                      setState(() {
                                        _fieldErrors['first_name'] = _validateRequired(value, 'First name');
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  controller: _lastNameController,
                                  label: 'Last Name',
                                  hint: 'Doe',
                                  icon: Icons.person_outline,
                                  errorKey: 'last_name',
                                  onChanged: (value) {
                                    if (_fieldErrors['last_name'] != null) {
                                      setState(() {
                                        _fieldErrors['last_name'] = _validateRequired(value, 'Last name');
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Middle Name (Optional)
                          _buildTextField(
                            controller: _middleNameController,
                            label: 'Middle Name',
                            hint: 'Enter middle name',
                            icon: Icons.badge_outlined,
                            errorKey: 'middle_name',
                            isOptional: true,
                          ),

                          const SizedBox(height: 18),

                          // Username
                          _buildTextField(
                            controller: _usernameController,
                            label: 'Username',
                            hint: 'Choose a unique username',
                            icon: Icons.alternate_email,
                            errorKey: 'username',
                            onChanged: (value) {
                              if (_fieldErrors['username'] != null) {
                                setState(() {
                                  _fieldErrors['username'] = _validateUsername(value);
                                });
                              }
                            },
                          ),

                          const SizedBox(height: 18),

                          // Email
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            hint: 'example@email.com',
                            icon: Icons.email_outlined,
                            errorKey: 'email',
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) {
                              if (_fieldErrors['email'] != null) {
                                setState(() {
                                  _fieldErrors['email'] = _validateEmail(value);
                                });
                              }
                            },
                          ),

                          const SizedBox(height: 18),

                          // Phone
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hint: '08012345678',
                            icon: Icons.phone_outlined,
                            errorKey: 'phone',
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            onChanged: (value) {
                              if (_fieldErrors['phone'] != null) {
                                setState(() {
                                  _fieldErrors['phone'] = _validatePhone(value);
                                });
                              }
                            },
                          ),

                          const SizedBox(height: 18),

                          // Password
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'Create a strong password',
                            icon: Icons.lock_outline,
                            errorKey: 'password',
                            obscureText: _obscurePassword,
                            onChanged: (value) {
                              if (_fieldErrors['password'] != null) {
                                setState(() {
                                  _fieldErrors['password'] = _validatePassword(value);
                                });
                              }
                            },
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey.shade500,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),

                          // Password requirements hint
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 6),
                                Text(
                                  'Minimum 6 characters',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Referral Code (Optional)
                          _buildTextField(
                            controller: _referralCodeController,
                            label: 'Referral Code',
                            hint: 'Enter referrer\'s username (optional)',
                            icon: Icons.card_giftcard_outlined,
                            errorKey: 'referral_code',
                            isOptional: true,
                          ),

                          const SizedBox(height: 32),

                          // Register Button
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
                              onPressed: _loading ? null : _register,
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
                                          'Create Account',
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

                          const SizedBox(height: 24),

                          // Terms and conditions
                          Center(
                            child: Text.rich(
                              TextSpan(
                                text: 'By registering, you agree to our ',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Divider
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

                          const SizedBox(height: 20),

                          // Login Link
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 15,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                                  },
                                  child: Text(
                                    'Sign In',
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
