import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/auth_service.dart';
import '../../routes.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> with TickerProviderStateMixin {
  final List<TextEditingController> _pinControllers = List.generate(4, (_) => TextEditingController());
  final List<TextEditingController> _confirmPinControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());
  final List<FocusNode> _confirmPinFocusNodes = List.generate(4, (_) => FocusNode());
  
  bool _isLoading = false;
  bool _isConfirmStep = false;
  String? _errorMessage;
  String _enteredPin = '';
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_shakeController);
    
    // Auto-focus first PIN field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var controller in _confirmPinControllers) {
      controller.dispose();
    }
    for (var node in _pinFocusNodes) {
      node.dispose();
    }
    for (var node in _confirmPinFocusNodes) {
      node.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  String get _currentPin {
    return _pinControllers.map((c) => c.text).join();
  }

  String get _confirmPin {
    return _confirmPinControllers.map((c) => c.text).join();
  }

  void _onPinChanged(int index, String value, bool isConfirm) {
    final controllers = isConfirm ? _confirmPinControllers : _pinControllers;
    final focusNodes = isConfirm ? _confirmPinFocusNodes : _pinFocusNodes;
    
    setState(() => _errorMessage = null);
    
    if (value.isNotEmpty) {
      // Move to next field
      if (index < 3) {
        focusNodes[index + 1].requestFocus();
      } else {
        // Last digit entered
        focusNodes[index].unfocus();
        
        if (!isConfirm) {
          // First PIN complete - move to confirm step
          final pin = _currentPin;
          if (pin.length == 4) {
            setState(() {
              _enteredPin = pin;
              _isConfirmStep = true;
            });
            Future.delayed(const Duration(milliseconds: 100), () {
              _confirmPinFocusNodes[0].requestFocus();
            });
          }
        } else {
          // Confirm PIN complete - validate and submit
          _validateAndSubmit();
        }
      }
    }
  }

  void _onPinBackspace(int index, bool isConfirm) {
    final controllers = isConfirm ? _confirmPinControllers : _pinControllers;
    final focusNodes = isConfirm ? _confirmPinFocusNodes : _pinFocusNodes;
    
    if (controllers[index].text.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
      controllers[index - 1].clear();
    }
  }

  void _validateAndSubmit() {
    if (_currentPin != _confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
      });
      _shakeController.forward(from: 0);
      // Clear confirm fields
      for (var controller in _confirmPinControllers) {
        controller.clear();
      }
      _confirmPinFocusNodes[0].requestFocus();
      return;
    }
    
    _submitPin();
  }

  void _goBackToFirstPin() {
    setState(() {
      _isConfirmStep = false;
      _enteredPin = '';
      _errorMessage = null;
    });
    for (var controller in _pinControllers) {
      controller.clear();
    }
    for (var controller in _confirmPinControllers) {
      controller.clear();
    }
    _pinFocusNodes[0].requestFocus();
  }

  Future<void> _submitPin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/create-pin'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'pin': _currentPin,
          'pin_confirmation': _confirmPin,
        }),
      );

      if (!mounted) return;

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Update local user data to reflect PIN is set
        await authService.refreshUserData();
        
        ToastHelper.showSuccess('PIN created successfully!');
        
        // Navigate to main screen
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.main);
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to create PIN. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error. Please try again.';
        _isLoading = false;
      });
    }
  }

  Widget _buildPinField(int index, bool isConfirm) {
    final controllers = isConfirm ? _confirmPinControllers : _pinControllers;
    final focusNodes = isConfirm ? _confirmPinFocusNodes : _pinFocusNodes;
    
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            isConfirm && _errorMessage != null ? _shakeAnimation.value : 0,
            0,
          ),
          child: child,
        );
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: focusNodes[index].hasFocus
                ? AppColors.primary
                : _errorMessage != null && isConfirm
                    ? Colors.red
                    : Colors.grey.shade300,
            width: focusNodes[index].hasFocus ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: focusNodes[index].hasFocus
                  ? AppColors.primary.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: TextField(
            controller: controllers[index],
            focusNode: focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            obscureText: true,
            obscuringCharacter: '●',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (value) => _onPinChanged(index, value, isConfirm),
            onSubmitted: (_) {},
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Header with back button (only on confirm step)
              if (_isConfirmStep)
                GestureDetector(
                  onTap: _goBackToFirstPin,
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
              
              // Lock Icon
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse circle
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.9, end: 1.1),
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Container(
                          width: 130 * value,
                          height: 130 * value,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                    // Inner circle
                    Container(
                      width: 100,
                      height: 100,
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
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isConfirmStep ? Icons.check_circle_outline : Icons.lock_outline,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Title
              Center(
                child: Text(
                  _isConfirmStep ? 'Confirm Your PIN' : 'Create Your PIN',
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
                  _isConfirmStep
                      ? 'Re-enter your 4-digit PIN to confirm'
                      : 'Set up a 4-digit PIN to secure your transactions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // PIN Input Fields
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 12,
                      ),
                      child: _buildPinField(index, _isConfirmStep),
                    );
                  }),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Error Message
              if (_errorMessage != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
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
              
              const SizedBox(height: 48),
              
              // Loading indicator
              if (_isLoading)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text(
                        'Setting up your PIN...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 40),
              
              // Security Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.security,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keep Your PIN Safe',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your PIN will be required for all transactions. Never share it with anyone.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
