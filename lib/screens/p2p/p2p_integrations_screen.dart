import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import '../../models/p2p/p2p.dart';
import '../../services/auth_service.dart';
import '../../services/p2p_service.dart';
import 'p2p_connect_provider_sheet.dart';

/// Exchange & bank integrations screen. The Bank tab is only shown when the
/// merchant's payout_mode is DOHIFY_MANAGED — i.e. "Connect My Own Account"
/// in the Settings screen's wording, where the user connects their own bank
/// so payouts execute straight from it. In SELF_MANAGED mode ("Managed by
/// Eziplug"), Eziplug settles trades on the user's behalf and no bank
/// connection from the user is needed, so the Bank tab is hidden.
class P2pIntegrationsScreen extends StatefulWidget {
  const P2pIntegrationsScreen({super.key});

  @override
  State<P2pIntegrationsScreen> createState() => _P2pIntegrationsScreenState();
}

class _P2pIntegrationsScreenState extends State<P2pIntegrationsScreen> {
  late final P2pService _service;
  bool _isLoading = true;
  bool _showBankTab = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = P2pService(
      authService: Provider.of<AuthService>(context, listen: false),
    );
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _service.getStatus();
    if (!mounted) return;
    if (result['success'] == true) {
      final status = result['status'] as P2pMerchantStatus?;
      setState(() {
        _showBankTab = status?.isDohifyManaged ?? false;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Failed to load status';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Integrations')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Integrations')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadStatus, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final tabCount = _showBankTab ? 2 : 1;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Integrations'),
          backgroundColor: isDark ? AppColors.headerDark : AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
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
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: [
                  const Tab(
                    height: 38,
                    icon: Icon(Icons.currency_exchange_rounded, size: 16),
                    iconMargin: EdgeInsets.only(bottom: 2),
                    text: 'Exchange',
                  ),
                  if (_showBankTab)
                    const Tab(
                      height: 38,
                      icon: Icon(Icons.account_balance_outlined, size: 16),
                      iconMargin: EdgeInsets.only(bottom: 2),
                      text: 'Bank',
                    ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _ProviderTab(category: 'exchange', service: _service),
            if (_showBankTab) _ProviderTab(category: 'bank', service: _service),
          ],
        ),
      ),
    );
  }
}

class _ProviderTab extends StatefulWidget {
  final String category;
  final P2pService service;

  const _ProviderTab({required this.category, required this.service});

  @override
  State<_ProviderTab> createState() => _ProviderTabState();
}

class _ProviderTabState extends State<_ProviderTab>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  String? _error;
  List<P2pProvider> _providers = [];
  final Set<String> _busyIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await widget.service.getProviders(category: widget.category);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _providers = (result['providers'] as List<P2pProvider>?) ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Failed to load providers';
        _isLoading = false;
      });
    }
  }

  Future<void> _connect(P2pProvider provider) async {
    final connected = await showP2pConnectProviderSheet(
      context,
      provider: provider,
      service: widget.service,
      category: widget.category,
    );
    if (connected == true) _load();
  }

  Future<void> _toggleActive(P2pProvider provider, bool value) async {
    setState(() => _busyIds.add(provider.id));
    final result = widget.category == 'exchange'
        ? await widget.service.setExchangeActive(provider.id, value)
        : await widget.service.setBankActive(provider.id, value);
    if (!mounted) return;
    setState(() => _busyIds.remove(provider.id));
    if (result['success'] == true) {
      ToastHelper.showSuccess(value ? 'Provider activated' : 'Provider deactivated');
      _load();
    } else {
      ToastHelper.showError(result['message']?.toString() ?? 'Failed to update provider');
    }
  }

  Future<void> _testConnection(P2pProvider provider) async {
    setState(() => _busyIds.add(provider.id));
    final result = await widget.service.testExchangeConnection(provider.id);
    if (!mounted) return;
    setState(() => _busyIds.remove(provider.id));
    if (result['success'] == true) {
      ToastHelper.showSuccess(result['message']?.toString() ?? 'Connection OK');
    } else {
      ToastHelper.showError(result['message']?.toString() ?? 'Connection test failed');
    }
  }

  Future<void> _disconnect(P2pProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Disconnect provider?'),
        content: Text(
          'This will remove your ${provider.name} connection. You can reconnect it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyIds.add(provider.id));
    final result = widget.category == 'exchange'
        ? await widget.service.deleteExchangeIntegration(provider.id)
        : await widget.service.deleteBankIntegration(provider.id);
    if (!mounted) return;
    setState(() => _busyIds.remove(provider.id));
    if (result['success'] == true) {
      ToastHelper.showSuccess('Provider disconnected');
      _load();
    } else {
      ToastHelper.showError(result['message']?.toString() ?? 'Failed to disconnect');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

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
    if (_providers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.category == 'exchange'
                    ? Icons.currency_exchange_rounded
                    : Icons.account_balance_outlined,
                size: 44,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No ${widget.category} providers available',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _providers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _ProviderCard(
          provider: _providers[index],
          category: widget.category,
          isBusy: _busyIds.contains(_providers[index].id),
          onConnect: () => _connect(_providers[index]),
          onToggleActive: (v) => _toggleActive(_providers[index], v),
          onTest: () => _testConnection(_providers[index]),
          onDisconnect: () => _disconnect(_providers[index]),
        ),
      ),
    );
  }
}

/// A single exchange/bank provider card. Not-connected providers get one
/// prominent full-width gradient "Connect" call-to-action; connected
/// providers get a compact status chip, an active/inactive switch, and two
/// secondary pill actions (Test/Disconnect).
class _ProviderCard extends StatelessWidget {
  final P2pProvider provider;
  final String category;
  final bool isBusy;
  final VoidCallback onConnect;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onTest;
  final VoidCallback onDisconnect;

  const _ProviderCard({
    required this.provider,
    required this.category,
    required this.isBusy,
    required this.onConnect,
    required this.onToggleActive,
    required this.onTest,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    final connected = provider.isConnected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: connected ? AppColors.success.withOpacity(0.35) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.black.withOpacity(0.06)).withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProviderLogo(provider: provider, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    _StatusChip(connected: connected),
                  ],
                ),
              ),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                )
              else if (connected)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Switch(
                    value: provider.isActive,
                    activeThumbColor: accent,
                    onChanged: onToggleActive,
                  ),
                ),
            ],
          ),
          if (provider.balance != null ||
              provider.balanceError != null ||
              provider.virtualAccountNumber != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (provider.balance != null || provider.balanceError != null)
                    _infoLine(
                      theme,
                      icon: Icons.account_balance_wallet_outlined,
                      text: provider.balanceError != null
                          ? 'Balance unavailable — ${provider.balanceError}'
                          : 'Balance: ₦${provider.balance!.toStringAsFixed(2)}',
                      isError: provider.balanceError != null,
                    ),
                  if (provider.virtualAccountNumber != null) ...[
                    if (provider.balance != null || provider.balanceError != null)
                      const SizedBox(height: 6),
                    _infoLine(
                      theme,
                      icon: Icons.pin_outlined,
                      text: '${provider.virtualAccountBankName ?? ''} • '
                          '${provider.virtualAccountNumber} • '
                          '${provider.virtualAccountName ?? ''}',
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (!connected)
            _ConnectCta(
              label: 'Connect ${provider.name}',
              onTap: isBusy ? null : onConnect,
              accent: accent,
            )
          else
            Row(
              children: [
                if (category == 'exchange') ...[
                  Expanded(
                    child: _PillButton(
                      label: 'Test',
                      icon: Icons.wifi_tethering_rounded,
                      color: accent,
                      onTap: isBusy ? null : onTest,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: _PillButton(
                    label: 'Disconnect',
                    icon: Icons.link_off_rounded,
                    color: Colors.red,
                    onTap: isBusy ? null : onDisconnect,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _infoLine(
    ThemeData theme, {
    required IconData icon,
    required String text,
    bool isError = false,
  }) {
    final color = isError ? AppColors.error : theme.textTheme.bodySmall?.color?.withOpacity(0.75);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  final P2pProvider provider;
  final Color accent;

  const _ProviderLogo({required this.provider, required this.accent});

  @override
  Widget build(BuildContext context) {
    final hasLogo = provider.logoUrl != null && provider.logoUrl!.isNotEmpty;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: hasLogo
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, accent.withOpacity(0.7)],
              ),
        color: hasLogo ? Colors.white : null,
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? Padding(
              padding: const EdgeInsets.all(6),
              child: Image.network(
                provider.logoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    provider.name.isNotEmpty ? provider.name[0].toUpperCase() : '?',
                    style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                provider.name.isNotEmpty ? provider.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
    );
  }
}


class _StatusChip extends StatelessWidget {
  final bool connected;

  const _StatusChip({required this.connected});

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.success : Colors.grey.shade500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            connected ? 'Connected' : 'Not connected',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The primary "Connect" call-to-action — full width, gradient-filled,
/// elevated, with a trailing arrow to read clearly as the main action.
class _ConnectCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color accent;

  const _ConnectCta({required this.label, required this.onTap, required this.accent});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: disabled
                  ? [Colors.grey.shade400, Colors.grey.shade400]
                  : [accent, accent.withOpacity(0.75)],
            ),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: accent.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// A secondary pill-shaped action button (Test / Disconnect).
class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
