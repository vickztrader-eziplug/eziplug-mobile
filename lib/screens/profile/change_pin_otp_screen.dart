import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/auth_service.dart';
import 'new_pin_screen.dart';

class ChangePinOtpScreen extends StatefulWidget {
  const ChangePinOtpScreen({super.key});

  @override
  State<ChangePinOtpScreen> createState() => _ChangePinOtpScreenState();
}

class _ChangePinOtpScreenState extends State<ChangePinOtpScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  Timer? _timer;
  int _secondsRemaining = 180;
  bool _isTimeUp = false;
  bool _isLoading = false;
  bool _isSendingOtp = true;
  bool _isVerifying = false;
  String? _errorMessage;
  String _userEmail = '';
  
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _loadUserEmail();
    _sendOtp();
  }

  void _loadUserEmail() {
    final authService = Provider.of<AuthService>(context, listen: false);
    setState(() {
      _userEmail = authService.userEmail;
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/otp'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ToastHelper.showSuccess(result['message'] ?? 'OTP sent to your email');
        _startTimer();
        setState(() => _isSendingOtp = false);
        
        // Focus first OTP field
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _focusNodes[0].requestFocus();
        });
      } else {
        setState(() {
          _isSendingOtp = false;
          _errorMessage = result['message'] ?? 'Failed to send OTP';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _errorMessage = 'Network error. Please try again.';
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 180;
      _isTimeUp = false;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _isTimeUp = true);
        timer.cancel();
      }
    });
  }

  String get _formattedTime {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _otp => _otpControllers.map((c) => c.text).join();

  void _onOtpChanged(int index, String value) {
    setState(() => _errorMessage = null);
    
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    
    // Auto-verify when all 6 digits entered
    if (_otp.length == 6) {
      _verifyOtp();
    }
  }

  void _onOtpBackspace(int index) {
    if (_otpControllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _otpControllers[index - 1].clear();
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': _userEmail,
          'otp': _otp,
        }),
      );

      if (!mounted) return;

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        ToastHelper.showSuccess('OTP verified successfully');
        
        // Navigate to new PIN screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NewPinScreen()),
        );
      } else {
        setState(() {
          _isVerifying = false;
          _errorMessage = result['message'] ?? 'Invalid OTP. Please try again.';
        });
        // Clear OTP fields
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Network error. Please try again.';
      });
    }
  }

  Future<void> _resendOtp() async {
    if (!_isTimeUp) return;
    
    // Clear old OTP
    for (var controller in _otpControllers) {
      controller.clear();
    }
    
    await _sendOtp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Widget _buildOtpField(int index) {
    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focusNodes[index].hasFocus
              ? AppColors.primary
              : _errorMessage != null
                  ? Colors.red.shade300
                  : Colors.grey.shade300,
          width: _focusNodes[index].hasFocus ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _focusNodes[index].hasFocus
                ? AppColors.primary.withOpacity(0.15)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) => _onOtpChanged(index, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isSendingOtp
            ? _buildSendingOtpView()
            : _buildOtpInputView(),
      ),
    );
  }

  Widget _buildSendingOtpView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1 + (_pulseController.value * 0.1),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.email_outlined,
                    size: 60,
                    color: AppColors.primary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'Sending OTP...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Please wait while we send a verification\ncode to your email',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildOtpInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Header Icon
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Title
          const Center(
            child: Text(
              'Verify Your Identity',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Subtitle
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'Enter the 6-digit code sent to\n'),
                  TextSpan(
                    text: _userEmail,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // OTP Input
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) => _buildOtpField(index)),
          ),
          
          const SizedBox(height: 20),
          
          // Error message
          if (_errorMessage != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Timer and Resend
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Didn\'t receive code? ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (_isTimeUp)
                  GestureDetector(
                    onTap: _resendOtp,
                    child: const Text(
                      'Resend',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formattedTime,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 48),
          
          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
              ),
              child: _isVerifying
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Verify & Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Security note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This verification is required to change your PIN for security purposes.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
