import 'dart:async';
// ignore: depend_on_referenced_packages
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import '../../models/p2p/p2p.dart';
import '../../services/auth_service.dart';
import '../../services/p2p_event_bus.dart';
import '../../services/p2p_service.dart';
import '../../services/p2p_socket_service.dart';
import '../../services/pdf_service.dart';
import '../transactions/transactions_screen.dart' show TransactionModel;

/// Full order detail: info card, merged status-history/events timeline, and
/// contextual action buttons that depend on the order's current status,
/// trade type, and the merchant's payout mode.
class P2pOrderDetailScreen extends StatefulWidget {
  final String orderId;

  const P2pOrderDetailScreen({super.key, required this.orderId});

  @override
  State<P2pOrderDetailScreen> createState() => _P2pOrderDetailScreenState();
}

class _P2pOrderDetailScreenState extends State<P2pOrderDetailScreen>
    with WidgetsBindingObserver {
  late final P2pService _service;
  late final AuthService _authService;
  bool _isLoading = true;
  bool _isActionInProgress = false;
  bool _isGeneratingReceipt = false;
  String? _error;
  P2pOrder? _order;
  List<P2pTimelineEntry> _timeline = [];
  bool _showMoreDetails = false;
  StreamSubscription<P2pOrderPushEvent>? _pushEventSub;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _service = P2pService(authService: _authService);
    WidgetsBinding.instance.addObserver(this);
    P2pSocketService.instance.acquire(_authService);
    // Refreshes as soon as a push about this exact order lands — a live
    // Reverb broadcast (P2pSocketService) or, as a fallback, an FCM push
    // received in the foreground — instead of relying on the trader to
    // pull-to-refresh or back out and back in.
    _pushEventSub = P2pEventBus.stream.listen((event) {
      if (mounted && !_isLoading && (event.orderId == null || event.orderId == widget.orderId)) {
        _load();
      }
    });
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_isLoading) {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushEventSub?.cancel();
    P2pSocketService.instance.release();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final results = await Future.wait([
      _service.getOrderDetail(widget.orderId),
      _service.getOrderHistory(widget.orderId),
      _service.getOrderEvents(widget.orderId),
    ]);
    if (!mounted) return;

    final detailResult = results[0];
    if (detailResult['success'] != true) {
      setState(() {
        _isLoading = false;
        _error = detailResult['message']?.toString() ?? 'Failed to load order';
      });
      return;
    }

    final historyResult = results[1];
    final eventsResult = results[2];
    final history = historyResult['success'] == true
        ? (historyResult['history'] as List<P2pOrderHistoryEntry>? ?? [])
        : <P2pOrderHistoryEntry>[];
    final events = eventsResult['success'] == true
        ? (eventsResult['events'] as List<P2pOrderEvent>? ?? [])
        : <P2pOrderEvent>[];

    final timeline = <P2pTimelineEntry>[
      ...history.map(P2pTimelineEntry.fromHistory),
      ...events.map(P2pTimelineEntry.fromEvent),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      _order = detailResult['order'] as P2pOrder?;
      _timeline = timeline;
      _isLoading = false;
    });
  }

  Future<void> _runAction(Future<Map<String, dynamic>> Function() action, {
    String? successMessage,
  }) async {
    setState(() => _isActionInProgress = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    if (result['success'] == true) {
      ToastHelper.showSuccess(
        successMessage ?? result['message']?.toString() ?? 'Action completed',
      );
      _load();
      // Dohify can keep advancing this order on its own seconds after we act
      // on it (e.g. auto-completing shortly after mark-pay) — the
      // DohifyOrderObserver -> Reverb broadcast this action's own DB update
      // triggers already covers that immediately; no separate guess-timer needed.
    } else {
      ToastHelper.showError(result['message']?.toString() ?? 'Action failed');
    }
  }

  Future<void> _reject() async {
    final reason = await _promptReason(
      title: 'Reject order',
      hint: 'Reason (optional)',
    );
    if (reason == null) return; // cancelled
    await _runAction(
      () => _service.manualApproval(
        widget.orderId,
        action: 'REJECT',
        reason: reason.isEmpty ? null : reason,
      ),
      successMessage: 'Order rejected',
    );
  }

  Future<void> _approvePayin() {
    return _runAction(
      () => _service.approvePayin(widget.orderId),
      successMessage: 'Payin approved',
    );
  }

  /// Builds a receipt straight from the order's own fields — deliberately
  /// not routed through the general transactions API, since a
  /// DOHIFY_MANAGED order never gets a local Payout/Transaction row (Dohify
  /// executes that transfer on its own connected account, not through
  /// Eziplug's wallet). Prefers order.transactionReference (Eziplug's own
  /// payout reference, set once our own auto-payout completes a self-managed
  /// order) and falls back to order.payoutReference (Dohify's own field,
  /// populated when Dohify itself executed the transfer) — a self-managed
  /// order can have the former without the latter ever being set on Dohify's
  /// side, so relying on payoutReference alone left the button hidden there.
  Future<void> _downloadReceipt() async {
    final order = _order;
    final ref = order?.transactionReference ?? order?.payoutReference;
    if (order == null || ref == null) return;

    setState(() => _isGeneratingReceipt = true);
    try {
      final senderName = '${_authService.userName} ${_authService.userLastName}'.trim();
      final receiverName = order.beneficiaryRealName ?? order.beneficiaryName ?? 'N/A';

      final transaction = TransactionModel(
        id: '',
        type: 'Payout',
        title: 'Transfer from $senderName to $receiverName | Eziplug',
        details: '',
        date: order.createdAt ?? DateTime.now(),
        amount: order.amount,
        status: 'COMPLETED',
        reference: ref,
        provider: 'system',
        rawData: {
          'sender': senderName,
          'recipient': receiverName,
          'bank_name': order.beneficiaryBank,
          'account_number': order.beneficiaryAccount,
          'account_name': receiverName,
        },
      );

      final file = await PdfService.generateReceiptImage(transaction);
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (mounted) ToastHelper.showError('Failed to generate receipt');
    } finally {
      if (mounted) setState(() => _isGeneratingReceipt = false);
    }
  }

  Future<void> _markDone() {
    return _runAction(
      () => _service.markDone(widget.orderId),
      successMessage: 'Order marked done',
    );
  }

  Future<void> _retry() {
    return _runAction(
      () => _service.retryOrder(widget.orderId),
      successMessage: 'Order queued for retry',
    );
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text('This will cancel this order. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      () => _service.cancelOrder(widget.orderId),
      successMessage: 'Order cancelled',
    );
  }

  Future<void> _markPay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as paid?'),
        content: const Text(
          'Eziplug will tell Dohify you have paid, without a receipt yet. Use "Pay" to actually pay the beneficiary and complete the order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      () => _service.markPay(widget.orderId),
      successMessage: 'Order marked as paid',
    );
  }

  /// What "Pay" actually does depends on the order's current state — same
  /// button, different underlying call, exactly like Dohify's own dashboard:
  ///   - self-managed: payNow() — the real Paystack transfer + receipt.
  ///   - Dohify-managed, still in review: manual-approval APPROVE — the
  ///     trigger for Dohify to execute the transfer on its own connected account.
  ///   - Dohify-managed, UNPAID_COMPLETED: pay-unpaid-completed — the actual
  ///     bank transfer for an order Bybit already shows as paid.
  /// Fires immediately, no confirmation step, since the trader already sees
  /// the amount and beneficiary on this screen before tapping.
  Future<void> _pay() {
    final order = _order;
    final Future<Map<String, dynamic>> Function() payAction;
    if (order == null || order.isSelfManaged) {
      payAction = () => _service.payNow(widget.orderId);
    } else if (order.status == P2pOrder.statusUnpaidCompleted) {
      payAction = () => _service.payUnpaidCompleted(widget.orderId);
    } else {
      payAction = () => _service.manualApproval(widget.orderId, action: 'APPROVE');
    }
    return _runAction(payAction, successMessage: 'Payment triggered');
  }

  Future<String?> _promptReason({required String title, required String hint}) async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Detail'),
        backgroundColor: isDark ? AppColors.headerDark : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _order == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Order not found'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final order = _order!;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildOrderCard(context, order),
              const SizedBox(height: 16),
              _buildActions(context, order),
              if ((order.transactionReference ?? order.payoutReference) != null) ...[
                const SizedBox(height: 10),
                _buildDownloadReceiptButton(context),
              ],
              if (_showMoreDetails) ...[
                const SizedBox(height: 20),
                Text(
                  'Timeline',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _buildTimeline(context),
              ],
            ],
          ),
        ),
        if (_isActionInProgress)
          Container(
            color: Colors.black38,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildOrderCard(BuildContext context, P2pOrder order) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                order.isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: order.isBuy ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${order.tradeType} #${order.providerOrderId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(order.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (order.status == P2pOrder.statusProcessing) ...[
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: _statusColor(order.status),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      order.status.replaceAll('_', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _statusColor(order.status),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _infoRow('Amount', '${order.fiatCurrency} ${order.amount.toStringAsFixed(2)}'),
          if ((order.beneficiaryRealName ?? order.beneficiaryName) != null)
            _infoRow('Beneficiary Name', (order.beneficiaryRealName ?? order.beneficiaryName)!),
          if (order.beneficiaryBank != null)
            _infoRow('Bank', order.beneficiaryBank!),
          if (order.beneficiaryAccount != null)
            _infoRow('Account', order.beneficiaryAccount!),
          if (order.payoutReference != null)
            _infoRow('Payout Ref', order.payoutReference!),
          if (order.transactionReference != null)
            _infoRow('Transaction Ref', order.transactionReference!),
          _infoRow('Sender Name', _authService.userFullName),
          if (_showMoreDetails) ...[
            const Divider(height: 24),
            _infoRow('Price', order.price.toStringAsFixed(2)),
            _infoRow('Quantity', '${order.qty} ${order.assetCurrency}'),
            if (order.reviewReason != null)
              _infoRow('Review Reason', order.reviewReason!.replaceAll('_', ' ')),
            if (order.exchangeProviderName != null)
              _infoRow('Exchange', order.exchangeProviderName!),
            if (order.payoutProviderName != null)
              _infoRow('Payout Provider', order.payoutProviderName!),
            if (order.counterpartyAvgTime != null)
              _infoRow('Counterparty Avg Time', order.counterpartyAvgTime!),
            if (order.counterpartyBadReviews != null)
              _infoRow('Counterparty Bad Reviews', '${order.counterpartyBadReviews}'),
            if (order.feeCollected != null)
              _infoRow('Fee Collected', order.feeCollected!.toStringAsFixed(2)),
            _infoRow('Payout Mode', order.payoutMode.replaceAll('_', ' ')),
            if (order.createdAt != null)
              _infoRow('Created', order.createdAt!.toLocal().toString()),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showMoreDetails = !_showMoreDetails),
              icon: Icon(
                _showMoreDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: accent,
                size: 18,
              ),
              label: Text(
                _showMoreDetails ? 'Hide Details' : 'More Details',
                style: TextStyle(color: accent, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Same mapping as the orders list screen's tile badge — PROCESSING gets
  /// its own color (plus a small spinner next to it) so a live status change
  /// arriving over the websocket reads as "actively being worked on" rather
  /// than just another badge that happens to say different text.
  Color _statusColor(String status) {
    switch (status) {
      case P2pOrder.statusCompleted:
        return AppColors.success;
      case P2pOrder.statusFailed:
      case P2pOrder.statusCancelled:
        return AppColors.error;
      case P2pOrder.statusManualReview:
        return AppColors.warning;
      case P2pOrder.statusProcessing:
      case P2pOrder.statusPending:
      case P2pOrder.statusPaidAwaitingReceipt:
        return AppColors.info;
      case P2pOrder.statusUnpaidCompleted:
        return AppColors.accentOrange;
      default:
        return Colors.grey;
    }
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, P2pOrder order) {
    final isManualReview = order.status == P2pOrder.statusManualReview;
    final isAwaitingSelfPayout = order.reviewReason == 'AWAITING_SELF_PAYOUT';

    final isUnpaidCompleted = order.status == P2pOrder.statusUnpaidCompleted;
    // Mirrors Dohify's own dashboard (OrdersPage.tsx): the same Mark Pay
    // (green) / Pay (red) pair for both payout modes — only what "Pay"
    // actually calls differs, branched inside _pay() itself.
    final selfManagedPayable = order.isSelfManaged && isManualReview && isAwaitingSelfPayout;
    final dohifyManagedInReview = order.isDohifyManaged && isManualReview && order.isBuy && !isAwaitingSelfPayout;

    final canReject = isManualReview && order.isBuy && order.isDohifyManaged;
    final canMarkPay = selfManagedPayable || dohifyManagedInReview;
    // review_reason reads as a historical "why this went to review" field on
    // Dohify's side rather than something cleared once resolved — a
    // COMPLETED order can still carry AWAITING_SELF_PAYOUT from before it was
    // paid, so self-managed eligibility must also check it's still in review.
    final canPay = selfManagedPayable ||
        order.status == P2pOrder.statusPaidAwaitingReceipt ||
        dohifyManagedInReview ||
        (order.isDohifyManaged && isUnpaidCompleted && order.isBuy);
    final canMarkDone = order.isDohifyManaged && isUnpaidCompleted && order.isBuy;
    final canApprovePayin = order.isSell &&
        (isManualReview ||
            order.status == P2pOrder.statusPending ||
            order.status == P2pOrder.statusProcessing);
    final canRetry = order.status == P2pOrder.statusFailed;
    final canCancel = order.status == P2pOrder.statusPending ||
        order.status == P2pOrder.statusProcessing;

    final buttons = <Widget>[];

    if (canMarkPay) {
      buttons.add(_primaryButton('Mark Pay', Icons.payment_rounded, _markPay, color: AppColors.success));
    }
    if (canPay) {
      buttons.add(_primaryButton('Pay', Icons.send_rounded, _pay, color: AppColors.error));
    }
    if (canMarkDone) {
      buttons.add(_secondaryButton('Mark Done', Icons.done_all_rounded, _markDone));
    }
    if (canReject) {
      buttons.add(_destructiveButton('Reject', Icons.cancel_outlined, _reject));
    }
    if (canApprovePayin) {
      buttons.add(_primaryButton('Approve Payin', Icons.download_done_rounded, _approvePayin));
    }
    if (canRetry) {
      buttons.add(_primaryButton('Retry', Icons.refresh_rounded, _retry));
    }
    if (canCancel) {
      buttons.add(_destructiveButton('Cancel Order', Icons.close_rounded, _cancel));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: buttons,
    );
  }

  Widget _buildDownloadReceiptButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: _isGeneratingReceipt ? null : _downloadReceipt,
        icon: _isGeneratingReceipt
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.download_rounded, size: 18, color: Colors.white),
        label: Text(
          _isGeneratingReceipt ? 'Preparing…' : 'Download Receipt',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback onTap, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color ?? (isDark ? AppColors.primaryLight : AppColors.primary);
    return ElevatedButton.icon(
      onPressed: _isActionInProgress ? null : onTap,
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _secondaryButton(String label, IconData icon, VoidCallback? onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    return OutlinedButton.icon(
      onPressed: (_isActionInProgress || onTap == null) ? null : onTap,
      icon: Icon(icon, size: 18, color: accent),
      label: Text(label, style: TextStyle(color: accent)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _destructiveButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: _isActionInProgress ? null : onTap,
      icon: Icon(icon, size: 18, color: Colors.red),
      label: Text(label, style: const TextStyle(color: Colors.red)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    if (_timeline.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No activity yet'),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    return Column(
      children: _timeline.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: entry.isEvent ? AppColors.info : accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (entry.subtitle != null && entry.subtitle!.isNotEmpty)
                      Text(
                        entry.subtitle!,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    Text(
                      entry.timestamp.toLocal().toString(),
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

