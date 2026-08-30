import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/p2p_service.dart';

/// Shown inline (not navigated to) by [P2pHomeScreen] whenever
/// `GET /p2p/status` reports `onboarded: false`. Calling [onOnboarded] tells
/// the parent to re-fetch status/dashboard and swap this out for the real
/// home content.
class P2pOnboardingScreen extends StatefulWidget {
  final VoidCallback onOnboarded;
  final P2pService? p2pService;

  const P2pOnboardingScreen({
    super.key,
    required this.onOnboarded,
    this.p2pService,
  });

  @override
  State<P2pOnboardingScreen> createState() => _P2pOnboardingScreenState();
}

class _P2pOnboardingScreenState extends State<P2pOnboardingScreen> {
  late final P2pService _service = widget.p2pService ?? P2pService();
  bool _isSubmitting = false;

  Future<void> _getStarted() async {
    setState(() => _isSubmitting = true);
    try {
      final result = await _service.onboard();
      if (!mounted) return;
      if (result['success'] == true) {
        ToastHelper.showSuccess(
          result['message']?.toString() ?? 'P2P Automation activated',
        );
        widget.onOnboarded();
      } else {
        ToastHelper.showError(
          result['message']?.toString() ?? 'Failed to activate P2P Automation',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sync_alt_rounded,
                  color: accent,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Automate your P2P trades',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Connect your crypto exchange P2P account and (optionally) a '
                'bank payout provider, and let Eziplug automatically settle '
                'your P2P trade orders — release, review and pay out orders '
                'without lifting a finger.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              _buildFeatureRow(
                context,
                Icons.bolt_rounded,
                'Instant automated settlement of eligible orders',
              ),
              _buildFeatureRow(
                context,
                Icons.rule_rounded,
                'Custom rules to control what gets auto-approved',
              ),
              _buildFeatureRow(
                context,
                Icons.shield_outlined,
                'Manual review for flagged or risky orders',
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _getStarted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Text(
                          'Get Started',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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

  Widget _buildFeatureRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isDark ? AppColors.primaryLight : AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.left,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
