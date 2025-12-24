import 'dart:async';
import 'package:cashpoint/routes.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart'; // adjust import

class ChangePinOtpScreen extends StatefulWidget {
  const ChangePinOtpScreen({super.key});
  // final String email;
  // const ChangePinOtpScreen({super.key, required this.email});
  @override
  State<ChangePinOtpScreen> createState() => _ChangePinOtpScreenState();
}

class _ChangePinOtpScreenState extends State<ChangePinOtpScreen>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _secondsRemaining = 180; // 3 minutes = 180 seconds
  bool _isTimeUp = false;

  late AnimationController _blinkController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    // Timer setup
    _startTimer();

    // Blinking animation setup (for when time hits zero)
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

  @override
  void dispose() {
    _timer.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const SizedBox(height: 40),
            Text(
              "Change PIN",
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
            const SizedBox(height: 30),
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
                    text: "adioridwan@example.com",
                    // text: widget.email,
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // OTP Input Boxes (Mock)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                6,
                (index) => Container(
                  height: 50,
                  width: 45,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Timer Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Resend OTP", style: TextStyle(fontSize: 16)),
                AnimatedBuilder(
                  animation: _blinkController,
                  builder: (context, child) {
                    return Text(
                      _isTimeUp ? "00:00" : _formattedTime,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isTimeUp ? _colorAnimation.value : Colors.black,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
              ],
            ),

            const Spacer(),

            // Verify Button
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.changePin);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Continue"),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
