import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/auth_service.dart';
import '../../routes.dart';

class ForgotPasswordScreenEnhanced extends StatefulWidget {
  const ForgotPasswordScreenEnhanced({super.key});

  @override
  State<ForgotPasswordScreenEnhanced> createState() => _ForgotPasswordScreenEnhancedState();
}

class _ForgotPasswordScreenEnhancedState extends State<ForgotPasswordScreenEnhanced>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Step management: 1 = email, 2 = OTP, 3 = new password
  int _currentStep = 1;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Individual field errors
  String? _emailError;
  String? _otpError;
  String? _passwordError;
  String? _confirmPasswordError;

  // OTP Controllers for individual boxes
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (index) => FocusNode());

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
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email address is required';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateOtp(String? value) {
    if (value == null || value.isEmpty) {
      return 'OTP is required';
    }
    if (value.length != 6) {
      return 'OTP must be 6 digits';
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

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String get _otpCode {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _sendResetOtp() async {
    setState(() {
      _emailError = _validateEmail(_emailController.text);
    });

    if (_emailError != null) return;

    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      final result = await auth.forgotPassword(_emailController.text.trim());
      setState(() => _loading = false);

      if (result['success'] == true) {
        ToastHelper.showSuccess(result['message'] ?? 'OTP sent to your email');
        setState(() {
          _currentStep = 2;
          _animationController.reset();
          _animationController.forward();
        });
      } else {
        ToastHelper.showError(result['message'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      setState(() => _loading = false);
      ToastHelper.showError('Network error. Please try again.');
    }
  }

  Future<void> _resetPassword() async {
    final otp = _otpCode;
    setState(() {
      _otpError = _validateOtp(otp);
      _passwordError = _validatePassword(_passwordController.text);
      _confirmPasswordError = _validateConfirmPassword(_confirmPasswordController.text);
    });

    if (_otpError != null || _passwordError != null || _confirmPasswordError != null) {
      return;
    }

    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      final result = await auth.resetPassword(
        email: _emailController.text.trim(),
        otp: otp,
        password: _passwordController.text.trim(),
        passwordConfirmation: _confirmPasswordController.text.trim(),
      );
      setState(() => _loading = false);

      if (result['success'] == true) {
        ToastHelper.showSuccess(result['message'] ?? 'Password reset successfully');
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      } else {
        ToastHelper.showError(result['message'] ?? 'Failed to reset password');
      }
    } catch (e) {
      setState(() => _loading = false);
      ToastHelper.showError('Network error. Please try again.');
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorText != null ? Colors.red.shade400 : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            readOnly: readOnly,
            focusNode: focusNode,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
              prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Text(
                errorText,
                style: TextStyle(color: Colors.red.shade400, fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOtpBoxes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter OTP',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (index) => Container(
              width: 48,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _otpError != null ? Colors.red.shade400 : Colors.grey.shade300,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _otpFocusNodes[index + 1].requestFocus();
                  } else if (value.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                  setState(() => _otpError = null);
                },
              ),
            ),
          ),
        ),
        if (_otpError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Text(
                _otpError!,
                style: TextStyle(color: Colors.red.shade400, fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepDot(1),
        _buildStepLine(1),
        _buildStepDot(2),
        _buildStepLine(2),
        _buildStepDot(3),
      ],
    );
  }

  Widget _buildStepDot(int step) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCurrent ? 36 : 28,
      height: isCurrent ? 36 : 28,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.grey.shade300,
        shape: BoxShape.circle,
        boxShadow: isCurrent ? [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: isCurrent ? 16 : 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine(int afterStep) {
    final isActive = _currentStep > afterStep;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 40,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  String get _stepTitle {
    switch (_currentStep) {
      case 1:
        return 'Forgot Password';
      case 2:
        return 'Verify OTP';
      case 3:
        return 'New Password';
      default:
        return 'Forgot Password';
    }
  }

  String get _stepSubtitle {
    switch (_currentStep) {
      case 1:
        return 'Enter your email address and we\'ll send you a verification code';
      case 2:
        return 'Enter the 6-digit code sent to ${_emailController.text}';
      case 3:
        return 'Create a new secure password for your account';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.grey.shade50,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Back button row
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () {
                                if (_currentStep > 1) {
                                  setState(() {
                                    _currentStep--;
                                    _animationController.reset();
                                    _animationController.forward();
                                  });
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Step indicator
                      _buildStepIndicator(),

                      const SizedBox(height: 40),

                      // Header icon
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _currentStep == 1 
                                ? Icons.lock_reset 
                                : _currentStep == 2 
                                    ? Icons.email_outlined 
                                    : Icons.lock_outline,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      Center(
                        child: Text(
                          _stepTitle,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Subtitle
                      Center(
                        child: Text(
                          _stepSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Step 1: Email
                      if (_currentStep == 1) ...[
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'Enter your email',
                          icon: Icons.email_outlined,
                          errorText: _emailError,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) => setState(() => _emailError = null),
                        ),
                      ],

                      // Step 2: OTP
                      if (_currentStep == 2) ...[
                        _buildOtpBoxes(),
                        const SizedBox(height: 20),
                        Center(
                          child: TextButton(
                            onPressed: _loading ? null : _sendResetOtp,
                            child: Text(
                              'Resend OTP',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Step 3: New Password
                      if (_currentStep == 3) ...[
                        _buildTextField(
                          controller: _passwordController,
                          label: 'New Password',
                          hint: 'Enter new password',
                          icon: Icons.lock_outline,
                          errorText: _passwordError,
                          obscureText: _obscurePassword,
                          onChanged: (_) => setState(() => _passwordError = null),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          hint: 'Confirm new password',
                          icon: Icons.lock_outline,
                          errorText: _confirmPasswordError,
                          obscureText: _obscureConfirmPassword,
                          onChanged: (_) => setState(() => _confirmPasswordError = null),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _loading ? null : () {
                            if (_currentStep == 1) {
                              _sendResetOtp();
                            } else if (_currentStep == 2) {
                              final otp = _otpCode;
                              setState(() {
                                _otpError = _validateOtp(otp);
                              });
                              if (_otpError == null) {
                                setState(() {
                                  _currentStep = 3;
                                  _animationController.reset();
                                  _animationController.forward();
                                });
                              }
                            } else {
                              _resetPassword();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            shadowColor: AppColors.primary.withOpacity(0.5),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  _currentStep == 1 
                                      ? 'Send Reset Code' 
                                      : _currentStep == 2 
                                          ? 'Verify Code' 
                                          : 'Reset Password',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Back to login
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Remember your password? ',
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
        ),
      ),
    ),
    );
  }
}
