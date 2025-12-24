import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  final String token;

  const VerificationScreen({super.key, this.email = '', this.token = ''});

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
      // TODO: Replace with your actual API service
      final response = await _verifyOtpApi(widget.email, otp);

      if (response['success']) {
        _showSnackBar('Verification successful!', Colors.green);
        // Navigate to login or home screen
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        _showSnackBar(response['message'] ?? 'Verification failed', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _verifyOtpApi(String email, String otp) async {
    // TODO: Implement your actual API call
    // Example:
    // final response = await http.post(
    //   Uri.parse('YOUR_API_URL/verify'),
    //   headers: {'Content-Type': 'application/json'},
    //   body: jsonEncode({
    //     'email': email,
    //     'otp': otp,
    //   }),
    // );
    // return jsonDecode(response.body);

    // Mock response for now
    await Future.delayed(const Duration(seconds: 2));
    return {'success': true, 'message': 'Verification successful'};
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
      // TODO: Replace with your actual API service
      final response = await _resendOtpApi(widget.email);

      if (response['success']) {
        _showSnackBar('OTP resent successfully', Colors.green);
        setState(() {
          _secondsRemaining = 180;
          _isTimeUp = false;
        });
        _startTimer();
      } else {
        _showSnackBar(
          response['message'] ?? 'Failed to resend OTP',
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _resendOtpApi(String email) async {
    // TODO: Implement your actual API call
    // Mock response for now
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true, 'message': 'OTP resent'};
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
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
                  style: textTheme.bodyMedium?.copyWith(color: Colors.black87),
                  children: [
                    const TextSpan(
                      text: "Enter the 6 digit OTP sent to your email ",
                    ),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // OTP Input Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => SizedBox(
                    height: 55,
                    width: 45,
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  ),
                ),
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
                        color: _isTimeUp ? Colors.blueAccent : Colors.grey,
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

              const Spacer(),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
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
                    Navigator.pushReplacementNamed(context, '/register');
                  },
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.black87),
                      children: [
                        TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: "Register Here!",
                          style: TextStyle(
                            color: Colors.blueAccent,
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
    );
  }
}
