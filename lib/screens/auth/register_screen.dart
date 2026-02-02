import 'package:cashpoint/screens/auth/verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_response.dart';
import '../../routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    // Email regex pattern
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // Phone validation
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove any non-digit characters
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length != 11) {
      return 'Phone number must be exactly 11 digits';
    }

    return null;
  }

  // Future<void> _register() async {
  //   if (!_formKey.currentState!.validate()) return;

  //   setState(() => _loading = true);
  //   final auth = Provider.of<AuthService>(context, listen: false);

  //   final data = {
  //     "first_name": _firstNameController.text.trim(),
  //     "last_name": _lastNameController.text.trim(),
  //     "middle_name": _middleNameController.text.trim(),
  //     "username": _usernameController.text.trim(),
  //     "email": _emailController.text.trim(),
  //     "phone": _phoneController.text.trim(),
  //     "password": _passwordController.text.trim(),
  //   };

  //   try {
  //     final result = await auth.register(data);

  //     if (!mounted) return;

  //     setState(() => _loading = false);

  //     print('Registration result: $result');

  //     // Check if registration was successful using 'status' field
  //     if (result['status'] == true) {
  //       // Extract token from nested structure: results.token
  //       final token = result['results']?['token'] ?? '';
  //       final email = _emailController.text.trim();

  //       print('Token extracted: $token');
  //       print('Email: $email');

  //       // Show success toast with GREEN background
  //       await Fluttertoast.showToast(
  //         msg:
  //             result['message'] ??
  //             "Registration successful! Please verify your email.",
  //         backgroundColor: Colors.green,
  //         textColor: Colors.white,
  //         fontSize: 16.0,
  //         toastLength: Toast.LENGTH_SHORT,
  //         gravity: ToastGravity.TOP,
  //       );

  //       // Navigate to verification screen
  //       // if (!mounted) return;

  //       // print('Navigating to verification screen...');

  //       // Use pushReplacement to prevent going back to registration
  //       // ignore: use_build_context_synchronously
  //       Navigator.of(context).pushReplacement(
  //         MaterialPageRoute(
  //           builder: (context) =>
  //               VerificationScreen(email: email, token: token),
  //         ),
  //       );

  //       print('Navigation completed');
  //     } else {
  //       // Registration failed - show error message
  //       await Fluttertoast.showToast(
  //         msg: result['message'] ?? "Registration failed.",
  //         backgroundColor: Colors.red,
  //         textColor: Colors.white,
  //         fontSize: 16.0,
  //         toastLength: Toast.LENGTH_LONG,
  //         gravity: ToastGravity.TOP,
  //       );
  //     }
  //   } catch (e) {
  //     print('Registration error: $e');
  //     if (!mounted) return;
  //     setState(() => _loading = false);
  //     await Fluttertoast.showToast(
  //       msg: "Something went wrong: $e",
  //       backgroundColor: Colors.red,
  //       textColor: Colors.white,
  //       fontSize: 16.0,
  //       toastLength: Toast.LENGTH_LONG,
  //       gravity: ToastGravity.TOP,
  //     );
  //   }
  // }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

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
    };

    try {
      final result = await auth.register(data);

      if (!mounted) return;

      setState(() => _loading = false);

      print('Registration result: $result');

      // Check if registration was successful using helper (handles both 'success' and 'status')
      if (isSuccessResponse(result)) {
        // Extract token from response data (handles both formats)
        final responseData = getResponseData(result);
        final token = responseData['token'] ?? result['token'] ?? '';
        final email = _emailController.text.trim();

        print('Token extracted: $token');
        print('Email: $email');

        // Show success toast with GREEN background
        ToastHelper.showSuccess(
          getResponseMessage(result).isNotEmpty
              ? getResponseMessage(result)
              : "Registration successful! Please verify your email.",
        );

        // Small delay to let toast show
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to verification screen
        if (!mounted) return;

        print('Navigating to verification screen...');

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                VerificationScreen(email: email, token: token),
          ),
        );

        print('Navigation completed');
      } else {
        // Registration failed
        ToastHelper.showError(
          getResponseMessage(result).isNotEmpty
              ? getResponseMessage(result)
              : "Registration failed.",
        );
      }
    } catch (e) {
      print('Registration error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      ToastHelper.showError("Network error. Please try again later.");
    }
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.lightGrey, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('', style: TextStyle(fontWeight: FontWeight.w600)),
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
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Register !',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                      color: AppColors.text,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                labelText(context, 'First Name'),
                TextFormField(
                  controller: _firstNameController,
                  decoration: _inputDecoration('Enter First Name'),
                  validator: (value) =>
                      value!.isEmpty ? 'First name is required' : null,
                ),
                const SizedBox(height: 16),

                labelText(context, 'Last Name'),
                TextFormField(
                  controller: _lastNameController,
                  decoration: _inputDecoration('Last Name'),
                  validator: (value) =>
                      value!.isEmpty ? 'Last name is required' : null,
                ),
                const SizedBox(height: 16),

                labelText(context, 'Middle Name'),
                TextFormField(
                  controller: _middleNameController,
                  decoration: _inputDecoration('Middle Name (optional)'),
                ),
                const SizedBox(height: 16),

                labelText(context, 'Username'),
                TextFormField(
                  controller: _usernameController,
                  decoration: _inputDecoration('Username'),
                  validator: (value) =>
                      value!.isEmpty ? 'Username is required' : null,
                ),
                const SizedBox(height: 16),

                labelText(context, 'Email Address'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('Email Address'),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),

                labelText(context, 'Phone Number'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Phone Number (11 digits)'),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: _validatePhone,
                ),
                const SizedBox(height: 16),

                labelText(context, 'Password'),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration('Password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) =>
                      value!.length < 6 ? 'Password too short' : null,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Register',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.login,
                        );
                      },
                      child: Text(
                        'Login here',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
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
