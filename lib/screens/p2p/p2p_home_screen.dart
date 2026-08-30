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
import 'p2p_onboarding_screen.dart';

/// Main landing screen for the P2P Automation feature — the destination of
/// the "P2P Automation" tile on the More Services grid.
class P2pHomeScreen extends StatefulWidget {
  const P2pHomeScreen({super.key});

  @override
  State<P2pHomeScreen> createState() => _P2pHomeScreenState();
}

class _P2pHomeScreenState extends State<P2pHomeScreen> {
  late final P2pService _service;
  bool _isLoading = true;
  bool _isTogglingAutoPayouts = false;
  String? _loadError;
  P2pMerchantStatus? _status;
  P2pDashboardStats? _stats;
  int? _pendingOrderCount;
  StreamSubscription<P2pOrderPushEvent>? _pushEventSub;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = P2pService(authService: authService);
    P2pSocketService.instance.acquire(authService);
    // Keeps the "Orders" badge accurate live, not just on the initial load —
    // an order clearing out of review while this screen sits in the
    // background (e.g. under the orders screen) shouldn't need a manual
    // pull-to-refresh to notice.
    _pushEventSub = P2pEventBus.stream.listen((_) {
      if (mounted && !_isLoading) _refreshPendingCount();
    });
    _loadAll();
  }

  @override
  void dispose() {
    _pushEventSub?.cancel();
    P2pSocketService.instance.release();
    super.dispose();
  }

  Future<void> _refreshPendingCount() async {
    final pending = await _service.getOrders(status: P2pOrder.activeStatuses, perPage: 1);
    if (!mounted || pending['success'] != true) return;
    final total = int.tryParse(pending['meta']?['total']?.toString() ?? '');
    if (total != null) setState(() => _pendingOrderCount = total);
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final statusResult = await _service.getStatus();
    if (!mounted) return;

    if (statusResult['success'] != true) {
      setState(() {
        _isLoading = false;
        _loadError = statusResult['message']?.toString() ?? 'Failed to load P2P status';
      });
      return;
    }

    final status = statusResult['status'] as P2pMerchantStatus?;
    if (status == null || !status.onboarded) {
      setState(() {
        _status = status;
        _stats = null;
        _isLoading = false;
      });
      return;
    }

    final dashboardResult = await _service.getDashboard();
    if (!mounted) return;

    setState(() {
      _status = status;
      _stats = dashboardResult['success'] == true
          ? dashboardResult['stats'] as P2pDashboardStats?
          : null;
      _isLoading = false;
      if (dashboardResult['success'] != true) {
        _loadError = dashboardResult['message']?.toString();
      }
    });

    // Sourced from Eziplug's own order mirror (same definition of "active"
    // the orders screen uses) rather than Dohify's dashboard stats, which
    // don't break the count down the same way — this is what actually
    // matches what the trader will see once they tap through.
    await _refreshPendingCount();
  }

  Future<void> _toggleAutoPayouts(bool value) async {
    setState(() => _isTogglingAutoPayouts = true);
    final result = await _service.updateSettings(autoPayoutsEnabled: value);
    if (!mounted) return;
    setState(() => _isTogglingAutoPayouts = false);

    if (result['success'] == true) {
      final current = _status;
      if (current != null) {
        setState(() {
          _status = P2pMerchantStatus(
            onboarded: current.onboarded,
            payoutMode: current.payoutMode,
            autoPayoutsEnabled: value,
            bypassNameCheck: current.bypassNameCheck,
            name: current.name,
            email: current.email,
            phone: current.phone,
            raw: current.raw,
          );
        });
      }
      ToastHelper.showSuccess(
        value ? 'Auto payouts enabled' : 'Auto payouts disabled',
      );
    } else {
      ToastHelper.showError(
        result['message']?.toString() ?? 'Failed to update settings',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('P2P Automation'),
        backgroundColor: isDark ? AppColors.headerDark : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && _status == null) {
      return _buildErrorState(_loadError!);
    }

    final status = _status;
    if (status == null || !status.onboarded) {
      return P2pOnboardingScreen(
        p2pService: _service,
        onOnboarded: _loadAll,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsSection(context, status, _stats),
          const SizedBox(height: 20),
          _buildAutoPayoutsCard(context, status),
          const SizedBox(height: 20),
          _buildNavigationGrid(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    P2pMerchantStatus status,
    P2pDashboardStats? stats,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cards = <Widget>[
      _statCard(
        context,
        label: 'Total Trades',
        value: '${stats?.totalTrades ?? 0}',
        icon: Icons.swap_horiz_rounded,
        color: isDark ? AppColors.primaryLight : AppColors.primary,
      ),
      _statCard(
        context,
        label: 'Success Rate',
        value: '${(stats?.successRate ?? 0).toStringAsFixed(1)}%',
        icon: Icons.check_circle_outline,
        color: AppColors.success,
      ),
      _statCard(
        context,
        label: 'Balance',
        // DOHIFY_MANAGED: the merchant's own connected payout provider
        // balance. SELF_MANAGED: there's no connected bank at all since
        // Eziplug settles on the user's behalf — show their Eziplug wallet
        // balance instead, so this card is always meaningful either way.
        value: status.isDohifyManaged
            ? (stats?.bankError != null
                ? 'N/A'
                : '₦${_formatMoney(stats?.bankBalance ?? 0)}')
            : '₦${_formatMoney(stats?.eziplugWalletBalance ?? 0)}',
        icon: status.isDohifyManaged
            ? Icons.account_balance_outlined
            : Icons.account_balance_wallet_outlined,
        color: AppColors.info,
      ),
      _statCard(
        context,
        label: 'Pending',
        value: '${stats?.manualReviewTrades ?? 0}',
        icon: Icons.flag_outlined,
        color: AppColors.error,
        showBadge: (stats?.manualReviewTrades ?? 0) > 0,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: cards,
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool showBadge = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              if (showBadge) ...[
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoPayoutsCard(BuildContext context, P2pMerchantStatus status) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.bolt_rounded, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto Payouts',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  status.autoPayoutsEnabled
                      ? 'Eligible orders settle automatically'
                      : 'Automation is currently paused',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          _isTogglingAutoPayouts
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Switch(
                  value: status.autoPayoutsEnabled,
                  activeThumbColor: accent,
                  onChanged: _toggleAutoPayouts,
                ),
        ],
      ),
    );
  }

  Widget _buildNavigationGrid(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final items = <_NavItem>[
      _NavItem(
        title: 'Orders',
        subtitle: 'Track & manage trades',
        icon: Icons.receipt_long_rounded,
        color: isDark ? AppColors.primaryLight : AppColors.primary,
        onTap: () => Navigator.pushNamed(context, AppRoutes.p2pOrders),
        badgeCount: _pendingOrderCount,
      ),
      _NavItem(
        title: 'Integrations',
        subtitle: 'Exchange & bank accounts',
        icon: Icons.link_rounded,
        color: AppColors.info,
        onTap: () => Navigator.pushNamed(context, AppRoutes.p2pIntegrations),
      ),
      _NavItem(
        title: 'Rules & Lists',
        subtitle: 'Automation rules',
        icon: Icons.rule_rounded,
        color: AppColors.accentPurple,
        onTap: () => Navigator.pushNamed(context, AppRoutes.p2pRules),
      ),
      _NavItem(
        title: 'Settings',
        subtitle: 'Payout mode & fees',
        icon: Icons.settings_outlined,
        color: AppColors.accentOrange,
        onTap: () => Navigator.pushNamed(context, AppRoutes.p2pSettings),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: item.onTap,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.icon, color: item.color),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                item.subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if ((item.badgeCount ?? 0) > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.badgeCount! > 99 ? '99+' : '${item.badgeCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }

  String _formatMoney(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
}

class _NavItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;

  _NavItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount,
  });
}
