import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../services/p2p_service.dart';

/// Shared "turn auto payout on/off" flow, used by both the P2P settings
/// screen and the orders list toggle so the two stay in sync instead of
/// carrying their own copies of this logic.
///
/// Mirrors Dohify's own dashboard toggle (DashboardOverview.tsx): turning it
/// on checks for orders already sitting in review — count *and* total value,
/// same as Dohify's manual_review_trades/manual_review_volume stat — and
/// offers to clear them as part of the same action, instead of leaving them
/// to be discovered later. Turning off has nothing to confirm.
class P2pAutoPayoutToggle {
  P2pAutoPayoutToggle._();

  /// Returns the new value on success (always `true` here), or null if the
  /// merchant cancelled or the request failed (toast already shown either way).
  static Future<bool?> turnOn(BuildContext context, P2pService service) async {
    final pending = await service.getOrders(status: 'MANUAL_REVIEW', tradeType: 'BUY', perPage: 1);
    final meta = pending['success'] == true ? pending['meta'] : null;
    final pendingCount = int.tryParse(meta?['total']?.toString() ?? '') ?? 0;
    final pendingAmount = double.tryParse(meta?['total_amount']?.toString() ?? '') ?? 0;

    bool triggerPending = false;
    if (pendingCount > 0) {
      if (!context.mounted) return null;
      final choice = await _showPendingOrdersDialog(context, pendingCount, pendingAmount);
      if (choice == null) return null; // cancelled
      triggerPending = choice;
    }

    final result = await service.updateSettings(autoPayoutsEnabled: true, triggerPendingPayouts: triggerPending);

    if (result['success'] == true) {
      ToastHelper.showSuccess(
        triggerPending
            ? 'Auto payout turned on — processing $pendingCount pending order(s)'
            : 'Auto payout turned on',
      );
      // No polling loop needed here anymore — every order this batch touches
      // broadcasts its own status change live over Reverb the instant the
      // backend updates it (DohifyOrderObserver), and any open P2P screen is
      // already listening on P2pEventBus for exactly that.
      return true;
    }

    ToastHelper.showError(result['message']?.toString() ?? 'Failed to turn on auto payout');
    return null;
  }

  /// Returns `false` on success, or null if the request failed.
  static Future<bool?> turnOff(P2pService service) async {
    final result = await service.updateSettings(autoPayoutsEnabled: false);

    if (result['success'] == true) {
      ToastHelper.showSuccess('Auto payout turned off');
      return false;
    }

    ToastHelper.showError(result['message']?.toString() ?? 'Failed to turn off auto payout');
    return null;
  }

  static final _currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);

  /// Returns true (process pending orders now), false (turn on only), or
  /// null (cancelled). Mirrors Dohify's own modal (DashboardOverview.tsx):
  /// icon + count/volume copy, then three full-width stacked buttons in
  /// priority order — primary action first, secondary second, cancel last.
  static Future<bool?> _showPendingOrdersDialog(BuildContext context, int count, double amount) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;

    return showDialog<bool?>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.pending_actions_rounded, color: accent, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                'Process pending orders?',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'You have '),
                    TextSpan(
                      text: '$count order${count == 1 ? '' : 's'}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                    ),
                    const TextSpan(text: ' waiting in review, totaling '),
                    TextSpan(
                      text: _currency.format(amount),
                      style: TextStyle(fontWeight: FontWeight.bold, color: accent),
                    ),
                    const TextSpan(text: '. Process them now, or just turn on auto payout for new orders going forward?'),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Turn On & Process',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Turn On Only',
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
