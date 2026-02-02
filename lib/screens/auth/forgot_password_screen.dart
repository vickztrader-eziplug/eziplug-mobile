import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../routes.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? savedEmail; // Add this parameter

  const ForgotPasswordScreen({super.key, this.savedEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePassword = true;

  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late FocusNode _passwordFocusNode;

  bool _isReturningUser = false;

  @override
  void initState() {
    super.initState();

    // Check if this is a returning user with saved email
    _isReturningUser =
        widget.savedEmail != null && widget.savedEmail!.isNotEmpty;

    // Pre-fill email if provided
    _emailController = TextEditingController(text: widget.savedEmail ?? '');
    _passwordController = TextEditingController();
    _passwordFocusNode = FocusNode();

    // Auto-focus password field if email is pre-filled
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
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _switchUser() {
    setState(() {
      _isReturningUser = false;
      _emailController.clear();
      _passwordController.clear();
    });
  }

  Widget labelText(BuildContext context, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.normal,
              color: AppColors.text,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);

    final data = {
      "email": _emailController.text.trim(),
      "password": _passwordController.text.trim(),
    };

    try {
      final result = await auth.login((data));
      final response = jsonEncode(result);
      setState(() => _loading = false);

      if (result['success'] == true) {
        ToastHelper.showSuccess(result['message'] ?? "Login successful");
        Navigator.pushReplacementNamed(context, AppRoutes.main);
      } else {
        ToastHelper.showError(result['message'] ?? "Invalid credentials");
      }
    } catch (e) {
      setState(() => _loading = false);
      print('Unexpected error: $e');
      ToastHelper.showError("Network error. Please try again later.");
    }
  }

  InputDecoration _inputDecoration(String hintText, {bool isReadOnly = false}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: isReadOnly,
      fillColor: isReadOnly ? Colors.grey[100] : null,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: AppColors.lightGrey, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Welcome back text
                const SizedBox(height: 40),

                // Different welcome message for returning users
                if (_isReturningUser) ...[
                  // User Avatar (first letter of email)
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        _emailController.text.isNotEmpty
                            ? _emailController.text[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Welcome Back!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Text(
                    _emailController.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your password to continue',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Forgot Password !',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                labelText(context, 'Email Address'),
                // Email / Username
                TextFormField(
                  controller: _emailController,
                  readOnly:
                      _isReturningUser, // Make read-only for returning users
                  decoration:
                      _inputDecoration(
                        'Email or Username',
                        isReadOnly: _isReturningUser,
                      ).copyWith(
                        suffixIcon: _isReturningUser
                            ? IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: _switchUser,
                                tooltip: 'Change email',
                              )
                            : null,
                      ),
                  validator: (value) =>
                      value!.isEmpty ? 'This field is required' : null,
                ),

                // "Not you?" link for returning users
                if (_isReturningUser) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _switchUser,
                      child: Text(
                        'Not you?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 150),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Register link (hide for returning users to reduce clutter)
                if (!_isReturningUser)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.register,
                          );
                        },
                        child: Text(
                          'Register here',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
