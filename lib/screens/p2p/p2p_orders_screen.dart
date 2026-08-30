import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import '../../models/p2p/p2p.dart';
import '../../routes.dart';
import '../../services/auth_service.dart';
import '../../services/p2p_event_bus.dart';
import '../../services/p2p_service.dart';
import '../../services/p2p_socket_service.dart';
import 'widgets/auto_payout_toggle.dart';
import 'widgets/beneficiary_edit_sheet.dart';

/// Order list screen. Top-level tabs split orders by trade direction —
/// "Payout" (BUY: the merchant pays fiat out to acquire crypto) and "Payin"
/// (SELL: the merchant receives fiat in for the crypto they release) — since
/// a single flat list mixing both directions plus every status got jampacked.
/// Within each tab, an Active/History toggle filters by status.
class P2pOrdersScreen extends StatefulWidget {
  const P2pOrdersScreen({super.key});

  @override
  State<P2pOrdersScreen> createState() => _P2pOrdersScreenState();
}

class _P2pOrdersScreenState extends State<P2pOrdersScreen> {
  late final P2pService _service;
  bool? _autoPayoutsEnabled; // null while loading
  bool _isTogglingAutoPayout = false;

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _service = P2pService(authService: _authService);
    // Acquired once for the whole screen (both BUY/SELL tabs share it)
    // rather than per-tab, so switching tabs doesn't reconnect the socket.
    P2pSocketService.instance.acquire(_authService);
    _loadAutoPayoutStatus();
  }

  @override
  void dispose() {
    P2pSocketService.instance.release();
    super.dispose();
  }

  Future<void> _loadAutoPayoutStatus() async {
    final result = await _service.getStatus();
    if (!mounted) return;
    if (result['success'] == true && result['status'] is P2pMerchantStatus) {
      setState(() => _autoPayoutsEnabled = (result['status'] as P2pMerchantStatus).autoPayoutsEnabled);
    }
  }

  Future<void> _onAutoPayoutToggled(bool value) async {
    setState(() => _isTogglingAutoPayout = true);
    final newValue = value ? await P2pAutoPayoutToggle.turnOn(context, _service) : await P2pAutoPayoutToggle.turnOff(_service);
    if (!mounted) return;
    setState(() {
      _isTogglingAutoPayout = false;
      if (newValue != null) _autoPayoutsEnabled = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('P2P Orders'),
          backgroundColor: isDark ? AppColors.headerDark : AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: isDark ? AppColors.headerDark : AppColors.primary,
                unselectedLabelColor: Colors.white,
                tabs: const [
                  _TradeDirectionTab(
                    icon: Icons.arrow_downward_rounded,
                    title: 'Payout',
                    subtitle: 'Buy Crypto',
                  ),
                  _TradeDirectionTab(
                    icon: Icons.arrow_upward_rounded,
                    title: 'Payin',
                    subtitle: 'Sell Crypto',
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _OrderListTab(
              service: _service,
              tradeType: 'BUY',
              autoPayoutsEnabled: _autoPayoutsEnabled,
              isTogglingAutoPayout: _isTogglingAutoPayout,
              onToggleAutoPayout: _onAutoPayoutToggled,
            ),
            _OrderListTab(
              service: _service,
              tradeType: 'SELL',
              autoPayoutsEnabled: _autoPayoutsEnabled,
              isTogglingAutoPayout: _isTogglingAutoPayout,
              onToggleAutoPayout: _onAutoPayoutToggled,
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeDirectionTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TradeDirectionTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 42,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14),
              const SizedBox(width: 4),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          Text(subtitle, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _OrderListTab extends StatefulWidget {
  final P2pService service;
  final String tradeType; // "BUY" | "SELL"
  final bool? autoPayoutsEnabled; // null while loading
  final bool isTogglingAutoPayout;
  final ValueChanged<bool> onToggleAutoPayout;

  const _OrderListTab({
    required this.service,
    required this.tradeType,
    required this.autoPayoutsEnabled,
    required this.isTogglingAutoPayout,
    required this.onToggleAutoPayout,
  });

  @override
  State<_OrderListTab> createState() => _OrderListTabState();
}

class _OrderListTabState extends State<_OrderListTab>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final List<P2pOrder> _orders = [];
  final Set<String> _processingOrderIds = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _showHistory = true;
  int? _activeCount;
  String? _error;
  int _page = 1;
  static const int _perPage = 20;
  StreamSubscription<P2pOrderPushEvent>? _pushEventSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    // Refreshes the instant a webhook-driven push lands, instead of the user
    // having to pull-to-refresh or wait to tap the notification.
    _pushEventSub = P2pEventBus.stream.listen((_) {
      if (mounted && !_isLoading) _load();
    });
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Covers a push that arrived while the app was backgrounded (foreground
    // FCM messages are the only ones P2pEventBus sees) — refresh once the
    // trader actually comes back to look at this screen.
    if (state == AppLifecycleState.resumed && mounted && !_isLoading) {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushEventSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String get _status => _showHistory ? P2pOrder.historyStatuses : P2pOrder.activeStatuses;

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _setShowHistory(bool value) {
    if (_showHistory == value) return;
    setState(() => _showHistory = value);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
    });
    final result = await widget.service.getOrders(
      status: _status,
      tradeType: widget.tradeType,
      page: _page,
      perPage: _perPage,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      final orders = (result['orders'] as List<P2pOrder>?) ?? [];
      final meta = result['meta'];
      setState(() {
        _orders
          ..clear()
          ..addAll(orders);
        _isLoading = false;
        _hasMore = _computeHasMore(meta, orders.length);
        // Already viewing Active — its own meta.total is the active count,
        // no need for a second request just to feed the badge.
        if (!_showHistory) {
          _activeCount = int.tryParse(meta?['total']?.toString() ?? '') ?? _activeCount;
        }
      });
      // Viewing History instead — the badge still needs to know how many
      // orders are waiting in Active, which this response can't tell it.
      if (_showHistory) _loadActiveCount();
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Failed to load orders';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadActiveCount() async {
    final result = await widget.service.getOrders(
      status: P2pOrder.activeStatuses,
      tradeType: widget.tradeType,
      perPage: 1,
    );
    if (!mounted || result['success'] != true) return;
    final total = int.tryParse(result['meta']?['total']?.toString() ?? '');
    if (total != null) setState(() => _activeCount = total);
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final result = await widget.service.getOrders(
      status: _status,
      tradeType: widget.tradeType,
      page: nextPage,
      perPage: _perPage,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      final orders = (result['orders'] as List<P2pOrder>?) ?? [];
      final meta = result['meta'];
      setState(() {
        _page = nextPage;
        _orders.addAll(orders);
        _isLoadingMore = false;
        _hasMore = _computeHasMore(meta, orders.length);
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  bool _computeHasMore(dynamic meta, int fetchedCount) {
    if (meta is Map) {
      final totalPages = int.tryParse(meta['total_pages']?.toString() ?? '');
      final page = int.tryParse(meta['page']?.toString() ?? '') ?? _page;
      if (totalPages != null) return page < totalPages;
    }
    // No pagination meta: degrade gracefully to a single page unless a full
    // page was returned, in which case we optimistically allow one more.
    return fetchedCount >= _perPage;
  }

  bool _isProcessing(P2pOrder order) => _processingOrderIds.contains(order.id);

  Future<void> _runTileAction(
    P2pOrder order,
    Future<Map<String, dynamic>> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _processingOrderIds.add(order.id));
    final result = await action();
    if (!mounted) return;
    setState(() => _processingOrderIds.remove(order.id));

    if (result['success'] == true) {
      ToastHelper.showSuccess(successMessage);
      _load();
      // Dohify can keep advancing this order on its own seconds after we act
      // on it (e.g. auto-completing shortly after mark-pay) — the
      // DohifyOrderObserver -> Reverb broadcast this action's own DB update
      // triggers already covers that immediately; no separate guess-timer needed.
    } else {
      ToastHelper.showError(result['message']?.toString() ?? 'Action failed');
    }
  }

  Future<void> _markPay(P2pOrder order) => _runTileAction(
        order,
        () => widget.service.markPay(order.id),
        successMessage: 'Marked as paid',
      );

  /// What "Pay" actually does depends on the order's current state — same
  /// button, different underlying call, exactly like Dohify's own dashboard:
  ///   - self-managed: payNow() — the real Paystack transfer + receipt.
  ///   - Dohify-managed, still in review: manual-approval APPROVE — the
  ///     trigger for Dohify to execute the transfer on its own connected account.
  ///   - Dohify-managed, UNPAID_COMPLETED: pay-unpaid-completed — the actual
  ///     bank transfer for an order Bybit already shows as paid.
  Future<void> _pay(P2pOrder order) {
    final Future<Map<String, dynamic>> Function() payAction;
    if (order.isSelfManaged) {
      payAction = () => widget.service.payNow(order.id);
    } else if (order.status == P2pOrder.statusUnpaidCompleted) {
      payAction = () => widget.service.payUnpaidCompleted(order.id);
    } else {
      payAction = () => widget.service.manualApproval(order.id, action: 'APPROVE');
    }
    return _runTileAction(order, payAction, successMessage: 'Payment triggered');
  }

  Future<void> _markDone(P2pOrder order) => _runTileAction(
        order,
        () => widget.service.markDone(order.id),
        successMessage: 'Order marked as completed',
      );

  Future<void> _approvePayin(P2pOrder order) => _runTileAction(
        order,
        () => widget.service.approvePayin(order.id),
        successMessage: 'Payin approved',
      );

  bool _canEditBeneficiary(P2pOrder order) {
    const terminal = {
      P2pOrder.statusCompleted,
      P2pOrder.statusCancelled,
      P2pOrder.statusFailed,
      P2pOrder.statusProcessedExternally,
    };
    return !terminal.contains(order.status);
  }

  Future<void> _editBeneficiary(P2pOrder order) async {
    final saved = await BeneficiaryEditSheet.show(
      context,
      service: widget.service,
      orderId: order.id,
      initialName: order.beneficiaryName,
      initialBank: order.beneficiaryBank,
      initialAccount: order.beneficiaryAccount,
    );
    if (saved) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              _statusFilterChip(label: 'History', selected: _showHistory, accent: accent, onTap: () => _setShowHistory(true)),
              const SizedBox(width: 8),
              _statusFilterChip(
                label: 'Active',
                selected: !_showHistory,
                accent: accent,
                onTap: () => _setShowHistory(false),
                badgeCount: _activeCount,
              ),
              const Spacer(),
              _buildAutoPayoutToggle(accent),
            ],
          ),
        ),
        Expanded(child: _buildList(theme)),
      ],
    );
  }

  Widget _statusFilterChip({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return Material(
      color: selected ? accent : accent.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withOpacity(0.28) : accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Same row as the Active/History filters, per the screen mock — lets the
  /// merchant flip auto payout without leaving this screen. Reflects and
  /// drives the same state as the P2P Settings screen's own toggle (both
  /// share P2pAutoPayoutToggle so the confirm-and-clear-pending flow is
  /// identical either way).
  Widget _buildAutoPayoutToggle(Color accent) {
    final enabled = widget.autoPayoutsEnabled;
    if (enabled == null) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Auto',
          style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 12),
        ),
        Switch(
          value: enabled,
          activeThumbColor: accent,
          onChanged: widget.isTogglingAutoPayout ? null : widget.onToggleAutoPayout,
        ),
      ],
    );
  }

  Widget _buildList(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    Text(
                      _showHistory ? 'No past orders yet' : 'No active orders right now',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _orders.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= _orders.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            );
          }
          return _buildOrderTile(context, _orders[index]);
        },
      ),
    );
  }

  Widget _buildOrderTile(BuildContext context, P2pOrder order) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(order.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.p2pOrderDetail,
          arguments: order.id,
        ).then((_) => _load()),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    order.isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: order.isBuy ? AppColors.success : AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${order.tradeType} • #${order.providerOrderId}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (order.status == P2pOrder.statusProcessing) ...[
                          SizedBox(
                            width: 9,
                            height: 9,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: statusColor),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          order.status.replaceAll('_', ' '),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${order.fiatCurrency} ${order.amount.toStringAsFixed(2)} • '
                '${order.qty} ${order.assetCurrency}',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (order.beneficiaryName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.beneficiaryBank != null
                            ? '${order.beneficiaryName!} - ${order.beneficiaryBank!}'
                            : order.beneficiaryName!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_canEditBeneficiary(order))
                      InkWell(
                        onTap: () => _editBeneficiary(order),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.edit_outlined, size: 15, color: Colors.grey.shade500),
                        ),
                      ),
                  ],
                ),
              ],
              if (order.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatDate(order.createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
              // Only worth showing while the order is still actionable — a
              // counterparty's release speed/bad-review history is context
              // for deciding whether to trust this trade, not a completed one.
              if (!_showHistory &&
                  (order.counterpartyAvgTime != null || (order.counterpartyBadReviews ?? 0) > 0)) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (order.counterpartyAvgTime != null) ...[
                      Icon(Icons.timer_outlined, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(
                        'Avg release ${order.counterpartyAvgTime}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                    if (order.counterpartyAvgTime != null && (order.counterpartyBadReviews ?? 0) > 0)
                      const SizedBox(width: 10),
                    if ((order.counterpartyBadReviews ?? 0) > 0) ...[
                      Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.error),
                      const SizedBox(width: 3),
                      Text(
                        '${order.counterpartyBadReviews} bad review${order.counterpartyBadReviews == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ],
              if (!_showHistory && order.errorMessage != null && order.errorMessage!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 11.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              _buildTileActions(context, order),
            ],
          ),
        ),
      ),
    );
  }

  /// Inline treat-it-now actions, so acting on an order doesn't require
  /// opening its detail page first. Mirrors Dohify's own dashboard exactly
  /// (dohify-frontend's OrdersPage.tsx): the same "Mark Pay" (green) / "Pay"
  /// (red) pair for BOTH payout modes, not just self-managed — only what
  /// "Pay" actually calls differs:
  ///   - SELF_MANAGED, awaiting payout: Mark Pay tells Dohify without moving
  ///     money yet; Pay actually pays (Paystack transfer + receipt) via
  ///     payNow(). Once marked, only Pay remains (PAID_AWAITING_RECEIPT).
  ///   - DOHIFY_MANAGED, in review (not a self-payout order): Mark Pay is the
  ///     same plain mark-pay call; Pay calls manual-approval APPROVE, which
  ///     is what makes Dohify execute the transfer on its own connected
  ///     account.
  ///   - DOHIFY_MANAGED, UNPAID_COMPLETED: Pay now calls pay-unpaid-completed
  ///     (the actual bank transfer trigger for an order Bybit already shows
  ///     as paid), alongside a secondary "Mark Done" for "I paid this myself
  ///     outside Dohify" — completes without triggering any transfer.
  Widget _buildTileActions(BuildContext context, P2pOrder order) {
    final isManualReview = order.status == P2pOrder.statusManualReview;
    final isAwaitingSelfPayout = order.reviewReason == 'AWAITING_SELF_PAYOUT';
    final isUnpaidCompleted = order.status == P2pOrder.statusUnpaidCompleted;

    final selfManagedPayable = order.isSelfManaged && isManualReview && isAwaitingSelfPayout;
    final dohifyManagedInReview = order.isDohifyManaged && isManualReview && order.isBuy && !isAwaitingSelfPayout;

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
    // Payin (SELL) side: confirming an incoming deposit before Dohify
    // releases the crypto — the counterpart to Mark Pay/Pay on the Payout
    // side, but its own dedicated endpoint (approve-payin), not manual-approval.
    final canApprovePayin = order.isSell &&
        (isManualReview ||
            order.status == P2pOrder.statusPending ||
            order.status == P2pOrder.statusProcessing);

    if (!canMarkPay && !canPay && !canMarkDone && !canApprovePayin) {
      return const SizedBox.shrink();
    }

    final busy = _isProcessing(order);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          if (canApprovePayin) ...[
            Expanded(
              child: _tileActionButton(
                label: 'Approve',
                color: AppColors.success,
                busy: busy,
                onTap: () => _approvePayin(order),
              ),
            ),
          ],
          if (canMarkPay) ...[
            Expanded(
              child: _tileActionButton(
                label: 'Mark Pay',
                color: AppColors.success,
                busy: busy,
                onTap: () => _markPay(order),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (canPay) ...[
            Expanded(
              child: _tileActionButton(
                label: 'Pay',
                color: AppColors.error,
                busy: busy,
                onTap: () => _pay(order),
              ),
            ),
            if (canMarkDone) const SizedBox(width: 8),
          ],
          if (canMarkDone)
            Expanded(
              child: _tileActionButton(
                label: 'Mark Done',
                color: AppColors.accentOrange,
                busy: busy,
                onTap: () => _markDone(order),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tileActionButton({
    required String label,
    required Color color,
    required bool busy,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        child: busy
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
