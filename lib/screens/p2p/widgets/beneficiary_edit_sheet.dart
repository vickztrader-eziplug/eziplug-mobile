import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../services/p2p_service.dart';

/// One entry from Eziplug's own `/payout/bank/list` — `{id, name, code,
/// slug, type}`, matching the `banks` table `BankNameMatcher`/Paystack use
/// for the actual payout transfer.
class _BankOption {
  final String code;
  final String name;

  const _BankOption({required this.code, required this.name});

  factory _BankOption.fromJson(Map<String, dynamic> json) {
    return _BankOption(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
    );
  }

  @override
  bool operator ==(Object other) => other is _BankOption && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Edit-beneficiary modal shared by the orders list (pencil icon next to the
/// beneficiary name) and the order detail screen. Mirrors Dohify's own
/// dashboard reactive verify pattern (OrdersPage.tsx: debounce the account
/// number, verify once a bank is selected and the account is 10 digits,
/// dedupe repeat verifies of the same bank+account pair) — but sources the
/// bank list and verification from Eziplug's own Paystack-backed endpoints
/// rather than Dohify's, since that's what the real payout transfer actually
/// uses. Bank first, then account number, then name — verifying resolves the
/// real name so the trader can confirm/correct what's declared against it.
class BeneficiaryEditSheet extends StatefulWidget {
  final P2pService service;
  final String orderId;
  final String? initialName;
  final String? initialBank;
  final String? initialAccount;

  const BeneficiaryEditSheet({
    super.key,
    required this.service,
    required this.orderId,
    this.initialName,
    this.initialBank,
    this.initialAccount,
  });

  /// Returns true if the beneficiary was saved (caller should refresh).
  static Future<bool> show(
    BuildContext context, {
    required P2pService service,
    required String orderId,
    String? initialName,
    String? initialBank,
    String? initialAccount,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BeneficiaryEditSheet(
        service: service,
        orderId: orderId,
        initialName: initialName,
        initialBank: initialBank,
        initialAccount: initialAccount,
      ),
    );
    return result ?? false;
  }

  @override
  State<BeneficiaryEditSheet> createState() => _BeneficiaryEditSheetState();
}

class _BeneficiaryEditSheetState extends State<BeneficiaryEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _accountController;
  final TextEditingController _bankMenuController = TextEditingController();

  List<_BankOption> _banks = [];
  _BankOption? _selectedBank;
  bool _loadingBanks = true;
  bool _isSaving = false;

  Timer? _verifyDebounce;
  String _lastVerifiedHash = '';
  bool _isVerifying = false;
  String? _resolvedName;
  bool? _nameMatches;
  String? _verifyError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _accountController = TextEditingController(text: widget.initialAccount ?? '');
    _accountController.addListener(_onAccountChanged);
    _loadBanks();
  }

  @override
  void dispose() {
    _verifyDebounce?.cancel();
    _bankMenuController.dispose();
    _nameController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    final result = await widget.service.getEziplugBanks();
    if (!mounted) return;

    if (result['success'] == true && result['data'] is List) {
      final banks = (result['data'] as List)
          .whereType<Map>()
          .map((e) => _BankOption.fromJson(Map<String, dynamic>.from(e)))
          .where((b) => b.code.isNotEmpty && b.name.isNotEmpty)
          .toList();

      _BankOption? preselected;
      final initialBank = widget.initialBank?.trim().toLowerCase();
      if (initialBank != null && initialBank.isNotEmpty) {
        for (final b in banks) {
          if (b.name.trim().toLowerCase() == initialBank) {
            preselected = b;
            break;
          }
        }
      }

      setState(() {
        _banks = banks;
        _loadingBanks = false;
        if (preselected != null) {
          _selectedBank = preselected;
          _bankMenuController.text = preselected.name;
        } else if (widget.initialBank != null) {
          // Couldn't match the stored free-text bank name to a known code —
          // show it as typed so the trader sees what's on file and can pick
          // the right one from the dropdown themselves.
          _bankMenuController.text = widget.initialBank!;
        }
      });
      _maybeVerify();
    } else {
      setState(() => _loadingBanks = false);
      ToastHelper.showError(result['message']?.toString() ?? 'Failed to load bank list');
    }
  }

  void _onBankSelected(_BankOption? bank) {
    setState(() {
      _selectedBank = bank;
      _resolvedName = null;
      _nameMatches = null;
      _verifyError = null;
    });
    _maybeVerify();
  }

  void _onAccountChanged() {
    setState(() {
      _resolvedName = null;
      _nameMatches = null;
      _verifyError = null;
    });
    _verifyDebounce?.cancel();
    _verifyDebounce = Timer(const Duration(milliseconds: 500), _maybeVerify);
  }

  void _maybeVerify() {
    final bank = _selectedBank;
    final account = _accountController.text.trim();
    if (bank == null || account.length != 10) return;

    final hash = '${bank.code}-$account';
    if (_lastVerifiedHash == hash) return; // avoid re-verifying the same pair

    _runVerify(bank, account, hash);
  }

  Future<void> _runVerify(_BankOption bank, String account, String hash) async {
    setState(() {
      _isVerifying = true;
      _verifyError = null;
    });

    final result = await widget.service.validateEziplugBankAccount(
      bankCode: bank.code,
      accountNumber: account,
    );
    if (!mounted) return;

    if (result['success'] == true && result['data'] is Map) {
      final accountName = result['data']['account_name']?.toString() ?? '';
      setState(() {
        _isVerifying = false;
        _resolvedName = accountName;
        _nameMatches = _looselyMatches(_nameController.text, accountName);
      });
      _lastVerifiedHash = hash;
    } else {
      setState(() {
        _isVerifying = false;
        _verifyError = result['message']?.toString() ?? 'Could not verify this account';
      });
    }
  }

  /// Rough client-side check just for the visual match/mismatch badge — the
  /// backend's own BankNameMatcher::verifyAccountName does the real,
  /// authoritative comparison before any money moves.
  bool _looselyMatches(String declared, String resolved) {
    final declaredTokens = declared.toLowerCase().split(RegExp(r'\s+')).where((t) => t.length > 1);
    final resolvedLower = resolved.toLowerCase();
    return declaredTokens.any(resolvedLower.contains);
  }

  Future<void> _save() async {
    final bank = _selectedBank;
    if (bank == null || _accountController.text.trim().isEmpty || _nameController.text.trim().isEmpty) {
      ToastHelper.showError('Choose a bank, enter the account number, and enter a name');
      return;
    }

    setState(() => _isSaving = true);
    final result = await widget.service.updateBeneficiary(
      widget.orderId,
      beneficiaryName: _nameController.text.trim(),
      beneficiaryBank: bank.name,
      beneficiaryAccount: _accountController.text.trim(),
      beneficiaryRealName: _resolvedName,
      nameMatched: _nameMatches,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      Navigator.of(context).pop(true);
      ToastHelper.showSuccess('Beneficiary updated');
    } else {
      ToastHelper.showError(result['message']?.toString() ?? 'Failed to update beneficiary');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Beneficiary',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildBankDropdown(),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Account Number',
                    border: const OutlineInputBorder(),
                    suffixIcon: _isVerifying
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                _buildVerificationStatus(theme),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Beneficiary Name', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {
                    if (_resolvedName != null) {
                      _nameMatches = _looselyMatches(_nameController.text, _resolvedName!);
                    }
                  }),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBankDropdown() {
    if (_loadingBanks) {
      return const InputDecorator(
        decoration: InputDecoration(labelText: 'Bank', border: OutlineInputBorder()),
        child: Row(
          children: [
            SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Loading banks…'),
          ],
        ),
      );
    }

    return DropdownMenu<_BankOption>(
      controller: _bankMenuController,
      width: MediaQuery.of(context).size.width - 40,
      enableFilter: true,
      enableSearch: true,
      requestFocusOnTap: true,
      label: const Text('Bank'),
      hintText: 'Select a bank',
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      initialSelection: _selectedBank,
      dropdownMenuEntries: _banks
          .map((b) => DropdownMenuEntry<_BankOption>(value: b, label: b.name))
          .toList(),
      onSelected: _onBankSelected,
    );
  }

  Widget _buildVerificationStatus(ThemeData theme) {
    if (_isVerifying) {
      return Text('Verifying account…', style: theme.textTheme.bodySmall);
    }

    if (_verifyError != null) {
      return Text(_verifyError!, style: const TextStyle(color: AppColors.error, fontSize: 12));
    }

    if (_resolvedName != null) {
      final matches = _nameMatches ?? false;
      final color = matches ? AppColors.success : AppColors.warning;
      return Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              matches ? 'Verified: $_resolvedName' : 'Resolved as "$_resolvedName" — doesn\'t match the name below',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
