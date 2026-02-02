import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// A beautiful, reusable PIN verification modal for transactions
/// 
/// Usage:
/// ```dart
/// final pin = await PinVerificationModal.show(
///   context: context,
///   title: 'Confirm Transaction',
///   subtitle: 'Enter your 4-digit PIN to confirm ₦5,000 airtime purchase',
///   amount: '₦5,000',
///   transactionType: 'Airtime Purchase',
/// );
/// 
/// if (pin != null) {
///   // Proceed with transaction using the PIN
/// }
/// ```
class PinVerificationModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? amount;
  final String? transactionType;
  final String? recipient;
  final VoidCallback? onForgotPin;

  const PinVerificationModal({
    super.key,
    this.title = 'Confirm Transaction',
    this.subtitle = 'Enter your 4-digit PIN to confirm',
    this.amount,
    this.transactionType,
    this.recipient,
    this.onForgotPin,
  });

  /// Show the PIN verification modal and return the entered PIN
  /// Returns null if user cancels, otherwise returns the 4-digit PIN
  static Future<String?> show({
    required BuildContext context,
    String title = 'Confirm Transaction',
    String? subtitle,
    String? amount,
    String? transactionType,
    String? recipient,
    VoidCallback? onForgotPin,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => PinVerificationModal(
        title: title,
        subtitle: subtitle ?? 'Enter your 4-digit PIN to confirm',
        amount: amount,
        transactionType: transactionType,
        recipient: recipient,
        onForgotPin: onForgotPin,
      ),
    );
  }

  @override
  State<PinVerificationModal> createState() => _PinVerificationModalState();
}

class _PinVerificationModalState extends State<PinVerificationModal>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  final int _pinLength = 4;
  bool _hasError = false;
  String? _errorMessage;
  
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
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
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
        // Return the PIN
        Navigator.pop(context, _pin);
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

  Widget _buildPinIndicator(int index, bool isSmallScreen) {
    final isFilled = index < _pin.length;
    final isActive = index == _pin.length;
    final size = isSmallScreen ? 44.0 : 56.0;
    final dotSize = isSmallScreen ? 12.0 : 16.0;
    
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_hasError ? _shakeAnimation.value * (index.isEven ? 1 : -1) : 0, 0),
          child: child,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 6 : 8),
        decoration: BoxDecoration(
          color: isFilled 
              ? (_hasError ? Colors.red.shade50 : AppColors.primary.withOpacity(0.1))
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
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
          boxShadow: isFilled ? [
            BoxShadow(
              color: (_hasError ? Colors.red : AppColors.primary).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Center(
          child: AnimatedScale(
            scale: isFilled ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: dotSize,
              height: dotSize,
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

  Widget _buildNumberButton(String number, {IconData? icon, Color? iconColor, bool isSmallScreen = false}) {
    final isBackspace = icon == Icons.backspace_outlined;
    final isEmpty = number.isEmpty && icon == null;
    
    // Smaller, more refined button sizes
    final buttonSize = isSmallScreen ? 52.0 : 60.0;
    final fontSize = isSmallScreen ? 20.0 : 24.0;
    final iconSize = isSmallScreen ? 20.0 : 22.0;
    
    // Empty placeholder for forgot button area
    if (isEmpty) {
      return SizedBox(width: buttonSize, height: buttonSize);
    }
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (icon == Icons.backspace_outlined) {
            _onBackspace();
          } else if (number.isNotEmpty) {
            _onNumberTap(number);
          }
        },
        onLongPress: isBackspace ? _onClear : null,
        borderRadius: BorderRadius.circular(buttonSize / 2),
        splashColor: AppColors.primary.withOpacity(0.15),
        highlightColor: AppColors.primary.withOpacity(0.08),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: isBackspace ? Colors.transparent : Colors.grey.shade100,
            shape: BoxShape.circle,
            border: isBackspace ? null : Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: isBackspace ? null : [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: icon != null
                ? Icon(
                    icon, 
                    size: iconSize, 
                    color: iconColor ?? Colors.grey.shade600,
                  )
                : Text(
                    number,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    
    // Use 75% of screen height like electricity provider modal for a cleaner look
    final sheetHeight = screenHeight * 0.75;
    
    return Container(
      height: sheetHeight + bottomPadding,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header with title and close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Lock Icon
                    Container(
                      padding: const EdgeInsets.all(8),
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
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Content area
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: isSmallScreen ? 16 : 20),
                  
                  // Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ),
                  
                  // Transaction Details Card
                  if (widget.amount != null || widget.transactionType != null || widget.recipient != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          if (widget.transactionType != null)
                            _buildDetailRow('Type', widget.transactionType!),
                          if (widget.recipient != null) ...[
                            if (widget.transactionType != null) const SizedBox(height: 8),
                            _buildDetailRow('Recipient', widget.recipient!),
                          ],
                          if (widget.amount != null) ...[
                            if (widget.transactionType != null || widget.recipient != null) 
                              const SizedBox(height: 8),
                            _buildDetailRow('Amount', widget.amount!, isAmount: true),
                          ],
                        ],
                      ),
                    ),
                  
                  SizedBox(height: isSmallScreen ? 20 : 28),
                  
                  // PIN Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pinLength,
                      (index) => _buildPinIndicator(index, isSmallScreen),
                    ),
                  ),
                  
                  // Error Message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  SizedBox(height: isSmallScreen ? 20 : 28),
                  
                  // Number Pad
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 32 : 48),
                    child: Column(
                      children: [
                        // Row 1: 1, 2, 3
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumberButton('1', isSmallScreen: isSmallScreen),
                            _buildNumberButton('2', isSmallScreen: isSmallScreen),
                            _buildNumberButton('3', isSmallScreen: isSmallScreen),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 14),
                        
                        // Row 2: 4, 5, 6
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumberButton('4', isSmallScreen: isSmallScreen),
                            _buildNumberButton('5', isSmallScreen: isSmallScreen),
                            _buildNumberButton('6', isSmallScreen: isSmallScreen),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 14),
                        
                        // Row 3: 7, 8, 9
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumberButton('7', isSmallScreen: isSmallScreen),
                            _buildNumberButton('8', isSmallScreen: isSmallScreen),
                            _buildNumberButton('9', isSmallScreen: isSmallScreen),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 14),
                        
                        // Row 4: Forgot, 0, Backspace
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Forgot PIN button
                            SizedBox(
                              width: isSmallScreen ? 56 : 68,
                              height: isSmallScreen ? 56 : 68,
                              child: widget.onForgotPin != null
                                  ? TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        widget.onForgotPin?.call();
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: Text(
                                        'Forgot?',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 11 : 12,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  : const SizedBox(),
                            ),
                            _buildNumberButton('0', isSmallScreen: isSmallScreen),
                            _buildNumberButton('', icon: Icons.backspace_outlined, isSmallScreen: isSmallScreen),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAmount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isAmount ? 16 : 14,
            fontWeight: isAmount ? FontWeight.bold : FontWeight.w600,
            color: isAmount ? AppColors.primary : Colors.black87,
          ),
        ),
      ],
    );
  }
}
