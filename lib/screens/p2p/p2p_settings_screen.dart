import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import '../../models/p2p/p2p.dart';
import '../../services/auth_service.dart';
import '../../services/p2p_service.dart';
import 'widgets/auto_payout_toggle.dart';

/// P2P automation settings: toggles, payout mode, and release message.
///
/// `payout_mode` naming is easy to misread, so the UI never shows the raw
/// wire values or the word "Dohify" to the end user:
///   - `payoutModeDohifyManaged` is shown as "Connect My Own Account" — the
///     user adds their own exchange/bank API keys and payouts execute
///     automatically straight from their connected account.
///   - `payoutModeSelfManaged` is shown as "Managed by Eziplug" — no bank
///     connection from the user is needed; Eziplug settles trades on their
///     behalf.
/// It's genuinely user-changeable per merchant (Eziplug's admin only sets
/// the platform-wide default for new signups), so it's never read-only here.
class P2pSettingsScreen extends StatefulWidget {
  const P2pSettingsScreen({super.key});

  @override
  State<P2pSettingsScreen> createState() => _P2pSettingsScreenState();
}

class _P2pSettingsScreenState extends State<P2pSettingsScreen> {
  late final P2pService _service;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  bool _autoPayoutsEnabled = false;
  bool _bypassNameCheck = false;
  String _payoutMode = P2pMerchantStatus.payoutModeSelfManaged;
  final TextEditingController _releaseMessageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = P2pService(
      authService: Provider.of<AuthService>(context, listen: false),
    );
    _load();
  }

  @override
  void dispose() {
    _releaseMessageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _service.getSettings();
    if (!mounted) return;
    if (result['success'] == true) {
      // GET /p2p/settings returns `{profile: {...live merchant fields...},
      // settings: {bybit_payment_message: "..."}}` — not a flat map.
      final data = result['data'];
      final root = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final profile = root['profile'] is Map
          ? Map<String, dynamic>.from(root['profile'] as Map)
          : <String, dynamic>{};
      final settings = root['settings'] is Map
          ? Map<String, dynamic>.from(root['settings'] as Map)
          : <String, dynamic>{};
      setState(() {
        _autoPayoutsEnabled = profile['auto_payouts_enabled'] == true;
        _bypassNameCheck = profile['bypass_name_check'] == true;
        _payoutMode = profile['payout_mode']?.toString() ??
            P2pMerchantStatus.payoutModeSelfManaged;
        _releaseMessageController.text = settings['bybit_payment_message']?.toString() ?? '';
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Failed to load settings';
        _isLoading = false;
      });
    }
  }

  /// Turning auto payout OFF is safe to just stage locally — the Save button
  /// persists it along with everything else, same as before. Turning it ON
  /// runs the shared confirm-and-clear-pending flow immediately (shared with
  /// the orders list's own toggle — see widgets/auto_payout_toggle.dart).
  Future<void> _onAutoPayoutsChanged(bool value) async {
    if (!value) {
      setState(() => _autoPayoutsEnabled = false);
      return;
    }

    setState(() => _isSaving = true);
    final newValue = await P2pAutoPayoutToggle.turnOn(context, _service);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (newValue != null) {
      setState(() => _autoPayoutsEnabled = newValue);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final result = await _service.updateSettings(
      autoPayoutsEnabled: _autoPayoutsEnabled,
      bypassNameCheck: _bypassNameCheck,
      payoutMode: _payoutMode,
      releaseMessage: _releaseMessageController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      ToastHelper.showSuccess(result['message']?.toString() ?? 'Settings saved');
    } else {
      ToastHelper.showError(result['message']?.toString() ?? 'Failed to save settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P Settings'),
        backgroundColor: isDark ? AppColors.headerDark : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;

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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          context,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto Payouts'),
              subtitle: const Text('Automatically settle eligible orders'),
              value: _autoPayoutsEnabled,
              activeThumbColor: accent,
              onChanged: _isSaving ? null : _onAutoPayoutsChanged,
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bypass Name Check'),
              subtitle: const Text('Skip beneficiary name matching before payout'),
              value: _bypassNameCheck,
              activeThumbColor: accent,
              onChanged: (v) => setState(() => _bypassNameCheck = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          context,
          title: 'Payout Mode',
          children: [
            Text(
              'Choose who settles the fiat side of your P2P trades.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 12),
            _payoutModeOption(
              context,
              value: P2pMerchantStatus.payoutModeDohifyManaged,
              title: 'Connect My Own Account',
              subtitle: 'Add your own exchange & bank details — payouts are '
                  'processed automatically straight from your connected account.',
            ),
            const SizedBox(height: 8),
            _payoutModeOption(
              context,
              value: P2pMerchantStatus.payoutModeSelfManaged,
              title: 'Managed by Eziplug',
              subtitle: 'No bank connection needed — Eziplug settles your '
                  'trades on your behalf.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          context,
          title: 'Release Message',
          children: [
            TextField(
              controller: _releaseMessageController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Message sent to counterparty when releasing/paying',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                  )
                : const Text(
                    'Save Settings',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _payoutModeOption(
    BuildContext context, {
    required String value,
    required String title,
    required String subtitle,
  }) {
    final selected = _payoutMode == value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _payoutMode = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? accent : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {String? title, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
          ],
          ...children,
        ],
      ),
    );
  }
}
