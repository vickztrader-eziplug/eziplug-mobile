// 1. Reusable PIN Entry Screen
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PinEntryOldScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Function(String) onPinComplete;
  final VoidCallback? onForgotPin;

  const PinEntryOldScreen({
    super.key,
    this.title = 'Confirm Payment',
    this.subtitle = 'Confirm payment by entering your 4 digit PIN',
    required this.onPinComplete,
    this.onForgotPin,
  });

  @override
  State<PinEntryOldScreen> createState() => _PinEntryOldScreenState();
}

class _PinEntryOldScreenState extends State<PinEntryOldScreen> {
  String _pin = '';
  final int _pinLength = 4;
  bool _isLoading = false;

  void _onNumberTap(String number) {
    if (_pin.length < _pinLength && !_isLoading) {
      setState(() {
        _pin += number;
      });

      if (_pin.length == _pinLength) {
        _submitPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty && !_isLoading) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _submitPin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onPinComplete(_pin);
    } catch (e) {
      // Reset PIN on error
      setState(() {
        _pin = '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
              ),

            // Header Section
            Container(
              width: double.infinity,
              height: 280,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Lock Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Section with curved top
            Positioned(
              top: 250,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // PIN Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pinLength,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: index < _pin.length
                                ? AppColors.primary
                                : AppColors.lightGrey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.lightGrey,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: _isLoading && index == _pin.length - 1
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    index < _pin.length ? '•' : '',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.onForgotPin != null)
                      TextButton(
                        onPressed: _isLoading ? null : widget.onForgotPin,
                        child: Text(
                          'Forgot transaction PIN',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textColor.withOpacity(0.6),
                          ),
                        ),
                      ),
                    const Spacer(),
                    // Number Pad
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        children: [
                          _buildNumberRow(['1', '2', '3']),
                          const SizedBox(height: 16),
                          _buildNumberRow(['4', '5', '6']),
                          const SizedBox(height: 16),
                          _buildNumberRow(['7', '8', '9']),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const SizedBox(width: 70),
                              _buildNumberButton('0'),
                              _buildBackspaceButton(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((number) => _buildNumberButton(number)).toList(),
    );
  }

  Widget _buildNumberButton(String number) {
    return GestureDetector(
      onTap: _isLoading ? null : () => _onNumberTap(number),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: _isLoading
              ? AppColors.lightGrey.withOpacity(0.1)
              : AppColors.lightGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: _isLoading
                  ? AppColors.textColor.withOpacity(0.3)
                  : AppColors.textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _onBackspace,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: _isLoading
              ? AppColors.lightGrey.withOpacity(0.1)
              : AppColors.lightGrey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            size: 28,
            color: _isLoading
                ? AppColors.textColor.withOpacity(0.3)
                : AppColors.textColor,
          ),
        ),
      ),
    );
  }
}
