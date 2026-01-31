import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/auth_service.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  final String token;

  const VerificationScreen({
    super.key,
    required this.email,
    required this.token,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _secondsRemaining = 180; // 3 minutes = 180 seconds
  bool _isTimeUp = false;
  bool _isLoading = false;

  late AnimationController _blinkController;
  late Animation<Color?> _colorAnimation;

  // OTP Controllers
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  @override
  void initState() {
    super.initState();
    _startTimer();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.red,
      end: Colors.transparent,
    ).animate(_blinkController);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _isTimeUp = true;
        });
        _timer.cancel();
      }
    });
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _otpCode {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCode;

    if (otp.length != 6) {
      _showSnackBar('Please enter complete 6-digit OTP', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      final result = await authService.verifyOtp(
        email: widget.email,
        otp: otp,
        token: widget.token,
      );

      print('OTP Verification Result: $result');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Check for 'success' field (from AuthService), not 'status'
      if (result['success'] == true) {
        _showSnackBar(
          result['message'] ?? 'Verification successful!',
          Colors.green,
        );

        // Wait a moment to show success message
        await Future.delayed(const Duration(milliseconds: 1000));

        // Navigate to login screen
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        _showSnackBar(
          result['message'] ?? 'Verification failed. Please check your OTP.',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _resendOtp() async {
    if (!_isTimeUp && _secondsRemaining > 0) {
      _showSnackBar('Please wait for timer to expire', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      final result = await authService.resendOtp(
        email: widget.email,
        token: widget.token,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _showSnackBar(
          result['message'] ?? 'OTP resent successfully',
          Colors.green,
        );

        setState(() {
          _secondsRemaining = 180;
          _isTimeUp = false;
        });
        _startTimer();

        // Clear OTP fields
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      } else {
        _showSnackBar(result['message'] ?? 'Failed to resend OTP', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    // Use ToastHelper for consistent top-positioned toasts
    ToastHelper.showSnackBar(context, message, color);
  }

  @override
  void dispose() {
    _timer.cancel();
    _blinkController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          // Added SingleChildScrollView to fix overflow
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    40,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back Button
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        // Check if we can pop, otherwise go to register
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacementNamed(context, '/register');
                        }
                      },
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),

                    const SizedBox(height: 20),

                    // Header
                    Text(
                      "Verification",
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      height: 2,
                      width: 80,
                      color: AppColors.primary,
                      margin: const EdgeInsets.only(top: 4, bottom: 24),
                    ),

                    // Description
                    const SizedBox(height: 20),
                    Text("Confirm OTP", style: textTheme.titleMedium),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.black87,
                        ),
                        children: [
                          const TextSpan(
                            text: "Enter the 6 digit OTP sent to your email ",
                          ),
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // OTP Input Boxes - Responsive layout to prevent overflow
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate box width based on available space
                        // 6 boxes with 5 gaps of 8px each = 40px for gaps
                        final boxWidth = (constraints.maxWidth - 40) / 6;
                        final clampedWidth = boxWidth.clamp(40.0, 55.0);
                        
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            6,
                            (index) => SizedBox(
                              height: 55,
                              width: clampedWidth,
                              child: TextField(
                                controller: _otpControllers[index],
                                focusNode: _focusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: _otpControllers[index].text.isNotEmpty
                                          ? AppColors.primary
                                          : Colors.grey.shade400,
                                      width: _otpControllers[index].text.isNotEmpty ? 1.5 : 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (value) {
                                  setState(() {}); // Rebuild to update border colors
                                  if (value.isNotEmpty && index < 5) {
                                    _focusNodes[index + 1].requestFocus();
                                  } else if (value.isEmpty && index > 0) {
                                    _focusNodes[index - 1].requestFocus();
                                  }
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Timer Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _isLoading ? null : _resendOtp,
                          child: Text(
                            "Resend OTP",
                            style: TextStyle(
                              fontSize: 16,
                              color: _isTimeUp
                                  ? AppColors.primary
                                  : Colors.grey,
                              fontWeight: _isTimeUp
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _blinkController,
                          builder: (context, child) {
                            return Text(
                              _isTimeUp ? "00:00" : _formattedTime,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isTimeUp
                                    ? _colorAnimation.value
                                    : Colors.black,
                                fontSize: 16,
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const Spacer(), // This will push content to bottom
                    // Verify Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Click to Verify",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87),
                            children: [
                              const TextSpan(text: "Already verified? "),
                              TextSpan(
                                text: "Login Here!",
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
