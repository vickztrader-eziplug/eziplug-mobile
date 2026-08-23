import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../core/widgets/pin_verification_modal.dart';
import '../../services/auth_service.dart';
import 'transaction_details_unified_screen.dart';

class BuyCryptoScreen extends StatefulWidget {
  final String cryptoName;
  final String cryptoId;
  /// Full coin data pre-loaded from TradeCryptoScreen (logo, rates, networks)
  /// so this screen doesn't need to re-fetch or show a coin picker. Falls
  /// back to fetching by [cryptoId]/[cryptoName] when reached without it
  /// (e.g. a future deep link) — the coin is still always locked, never
  /// user-pickable here.
  final Map<String, dynamic>? coin;
  const BuyCryptoScreen({super.key, required this.cryptoName, required this.cryptoId, this.coin});

  @override
  State<BuyCryptoScreen> createState() => _BuyCryptoScreenState();
}

class _BuyCryptoScreenState extends State<BuyCryptoScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _walletAddressController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingWallet = true;
  bool _isLoadingRate = true;
  double _walletNaira = 0.0;

  double _currentRate = 0.0; // NGN per 1 USD of crypto
  double _youReceive = 0.0;

  String? _selectedCoin;
  String? _selectedCoinId;
  String? _coinName;
  String? _coinLogo;
  List<Map<String, dynamic>> _networks = [];
  String? _selectedNetworkValue;
  String? _selectedNetworkLabel;

  @override
  void dispose() {
    _amountController.dispose();
    _walletAddressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Initialize with cached balance immediately so it doesn't show 0
    final authService = Provider.of<AuthService>(context, listen: false);
    _walletNaira = authService.walletNaira;
    if (_walletNaira > 0) {
      _isLoadingWallet = false;
    }
    _fetchWalletBalance();
    _loadCoinData();
    _amountController.addListener(_calculateYouReceive);
  }

  void _applyCoin(Map<String, dynamic> coin) {
    _selectedCoin = (coin['symbol'] ?? widget.cryptoName).toString();
    _selectedCoinId = (coin['id'] ?? widget.cryptoId).toString();
    _coinName = coin['name']?.toString();
    _coinLogo = coin['logo']?.toString();
    _currentRate = double.tryParse(coin['buy_rate_ngn']?.toString() ?? '0') ?? 0.0;
    _networks = (coin['networks'] is List)
        ? List<Map<String, dynamic>>.from(
            (coin['networks'] as List).map((n) => Map<String, dynamic>.from(n as Map)))
        : [];
    if (_networks.isNotEmpty) {
      _selectedNetworkValue = _networks.first['value']?.toString();
      _selectedNetworkLabel = _networks.first['label']?.toString();
    }
    _isLoadingRate = false;
  }

  Future<void> _fetchWalletBalance() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        setState(() => _isLoadingWallet = false);
        return;
      }

      final response = await http.get(
        Uri.parse(Constants.user),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final userData = responseData['data'] ?? responseData;

        if (mounted) {
          setState(() {
            _walletNaira =
                double.tryParse(userData['wallet_naira']?.toString() ?? '0') ?? 0.0;
            _isLoadingWallet = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  /// The coin is always locked to what was tapped on TradeCryptoScreen — this
  /// screen never lets the user pick a different coin. When [widget.coin] is
  /// already provided, use it directly with no network round trip; otherwise
  /// (e.g. a future deep link with just an id) fetch the coin list once to
  /// look up that one coin's full details.
  Future<void> _loadCoinData() async {
    if (widget.coin != null) {
      setState(() => _applyCoin(widget.coin!));
      _calculateYouReceive();
      return;
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.get(
        Uri.parse(Constants.cryptoTypes),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final data = responseData['data'] ?? responseData['results'] ?? responseData;

        List<dynamic> coinsList = [];
        if (data is List) {
          coinsList = data;
        } else if (data is Map && data['data'] is List) {
          coinsList = data['data'];
        }

        final coins = coinsList.map<Map<String, dynamic>>((coin) => {
          'id': coin['id']?.toString() ?? '',
          'symbol': (coin['symbol'] ?? coin['name'] ?? '').toString().toUpperCase(),
          'name': coin['name'] ?? coin['symbol'] ?? '',
          'logo': coin['logo']?.toString(),
          'buy_rate_ngn': double.tryParse(coin['buy_rate_ngn']?.toString() ?? '0') ?? 0.0,
          'networks': coin['networks'] is List ? coin['networks'] : [],
        }).toList();

        // Match by id first, fall back to symbol
        Map<String, dynamic>? match;
        if (widget.cryptoId.isNotEmpty) {
          match = coins.cast<Map<String, dynamic>?>().firstWhere(
            (c) => c!['id'] == widget.cryptoId,
            orElse: () => null,
          );
        }
        match ??= coins.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c!['symbol'] == widget.cryptoName.toUpperCase(),
          orElse: () => null,
        );

        if (mounted) {
          setState(() {
            if (match != null) {
              _applyCoin(match);
            } else {
              _selectedCoin = widget.cryptoName;
              _selectedCoinId = widget.cryptoId;
              _isLoadingRate = false;
            }
          });
          _calculateYouReceive();
        }
      } else if (mounted) {
        setState(() {
          _selectedCoin = widget.cryptoName;
          _selectedCoinId = widget.cryptoId;
          _isLoadingRate = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedCoin = widget.cryptoName;
          _selectedCoinId = widget.cryptoId;
          _isLoadingRate = false;
        });
      }
    }
  }

  void _onNetworkSelected(Map<String, dynamic> network) {
    setState(() {
      _selectedNetworkValue = network['value']?.toString();
      _selectedNetworkLabel = network['label']?.toString();
    });
  }

  void _calculateYouReceive() {
    final amountNaira = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    if (mounted) {
      setState(() {
        if (_currentRate > 0) {
          // amountNaira / rate = crypto amount
          _youReceive = amountNaira / _currentRate;
        } else {
          _youReceive = 0.0;
        }
      });
    }
  }

  Future<void> _proceedToPin() async {
    if (_selectedCoin == null) {
      _showSnackBar('Please select a coin', Colors.red);
      return;
    }

    if (_amountController.text.isEmpty) {
      _showSnackBar('Please enter amount in Naira', Colors.red);
      return;
    }

    final amountNaira = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amountNaira == null || amountNaira <= 0) {
      _showSnackBar('Please enter a valid amount', Colors.red);
      return;
    }

    if (_walletNaira < amountNaira) {
      _showSnackBar(
        'Insufficient balance (₦${_formatBalance(_walletNaira)}). Please fund your wallet.',
        Colors.red,
      );
      return;
    }

    if (_walletAddressController.text.isEmpty) {
      _showSnackBar('Please enter your wallet address', Colors.red);
      return;
    }

    if (_networks.isNotEmpty && _selectedNetworkValue == null) {
      _showSnackBar('Please select a network', Colors.red);
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();

    if (token == null || token.isEmpty) {
      _showSnackBar('Please login to continue', Colors.red);
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (!mounted) return;

    final pin = await PinVerificationModal.show(
      context: context,
      title: 'Confirm Purchase',
      subtitle: 'Enter your 4-digit PIN to buy $_selectedCoin',
      transactionType: 'Buy Crypto',
      amount: '₦${_formatBalance(amountNaira)}',
      recipient: '${_youReceive.toStringAsFixed(6)} $_selectedCoin',
      onForgotPin: () {
        _showSnackBar('Go to Profile > PIN Management to reset your PIN', Colors.orange);
      },
    );

    if (pin != null && pin.length == 4) {
      _buyCrypto(pin);
    }
  }

  Future<void> _buyCrypto(String pin) async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final amountNaira = double.parse(_amountController.text.replaceAll(',', ''));

      final response = await http.post(
        Uri.parse(Constants.buyCryptoUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'crypto_id': _selectedCoinId ?? widget.cryptoId,
          'amount_ngn': amountNaira,
          'wallet_address': _walletAddressController.text,
          if (_selectedNetworkValue != null) 'network': _selectedNetworkValue,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Update wallet balance
        if (responseData['new_balance'] != null) {
          setState(() {
            _walletNaira =
                double.tryParse(responseData['new_balance']?.toString() ?? '0') ??
                _walletNaira;
          });
        } else {
          setState(() => _walletNaira -= amountNaira);
        }

        final reference = responseData['reference']?.toString() ?? 
                         responseData['data']?['reference']?.toString() ??
                         responseData['transaction_id']?.toString();

        if (reference != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionDetailUnifiedScreen(
                transactionReference: reference,
              ),
            ),
          );
        } else {
          _showSnackBar('Purchase successful', Colors.green);
          Navigator.pop(context);
        }
      } else if (response.statusCode == 401) {
        _showSnackBar('Session expired. Please login again', Colors.red);
        await authService.logout();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      } else {
        _showSnackBar(
          responseData['message'] ?? 'Failed to buy ${_selectedCoin ?? widget.cryptoName}',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(ErrorHandler.getUserFriendlyMessage(e), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ToastHelper.showSnackBar(context, message, color);
  }

  String _formatBalance(double balance) {
    return balance
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  /// Circular coin logo with a graceful fallback to a lettered avatar when
  /// there's no logo or it fails to load.
  Widget _buildCoinLogo({double size = 44}) {
    final logoUrl = Constants.resolveLogoUrl(_coinLogo);
    final symbol = _selectedCoin ?? widget.cryptoName;

    Widget fallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(size / 2),
          ),
          child: Center(
            child: Text(
              symbol.isNotEmpty ? symbol.substring(0, 1) : '?',
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        );

    if (logoUrl == null) {
      debugPrint('[CryptoLogo] No logo for $symbol (raw="$_coinLogo")');
      return fallback();
    }

    return ClipOval(
      child: Image.network(
        logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null ? child : fallback(),
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[CryptoLogo] Failed to load "$logoUrl": $error');
          return fallback();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              // Modern Gradient Header
              ModernFormWidgets.buildGradientHeader(
                context: context,
                title: 'Receive ${_selectedCoin ?? widget.cryptoName}',
                walletBalance: _walletNaira,
                isLoadingBalance: _isLoadingWallet,
                primaryColor: AppColors.primary,
              ),

              // Content Section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Locked coin (selected on the previous screen)
                      ModernFormWidgets.buildFormCard(
                        child: Row(
                          children: [
                            _buildCoinLogo(size: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedCoin ?? widget.cryptoName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textTheme.titleMedium?.color,
                                    ),
                                  ),
                                  if (_coinName != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _coinName!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white60 : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Network Selection
                      if (_networks.isNotEmpty) ...[
                        ModernFormWidgets.buildFormCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ModernFormWidgets.buildSectionLabel(
                                'Select Network',
                                icon: Icons.hub_outlined,
                                iconColor: AppColors.accentTeal,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _networks.map((network) {
                                  final label = network['label']?.toString() ?? '';
                                  final isSelected = _selectedNetworkValue == network['value']?.toString();
                                  return ModernFormWidgets.buildSelectableChip(
                                    label: label,
                                    isSelected: isSelected,
                                    onTap: () => _onNetworkSelected(network),
                                    selectedColor: AppColors.accentTeal,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Make sure your wallet address below supports the '
                                '${_selectedNetworkLabel ?? 'selected'} network. '
                                'Sending to an address on a different network will result in loss of funds.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Amount Input
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Amount (₦)',
                              icon: Icons.payments_outlined,
                              iconColor: AppColors.primary,
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildTextField(
                              controller: _amountController,
                              hintText: 'Enter amount in Naira',
                              prefixIcon: Icons.money,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Wallet Address
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Wallet Address',
                              icon: Icons.account_balance_wallet_outlined,
                              iconColor: AppColors.accentTeal,
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildTextField(
                              controller: _walletAddressController,
                              hintText: 'Paste your wallet address',
                              prefixIcon: Icons.link_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Rate & Summary Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          children: [
                            _buildSummaryRow(
                              'Rate',
                              _isLoadingRate
                                  ? 'Loading...'
                                  : _currentRate > 0
                                      ? '₦${_formatBalance(_currentRate)} / 1 ${_selectedCoin ?? 'Crypto'}'
                                      : 'Rate unavailable',
                              icon: Icons.trending_up_rounded,
                              theme: theme,
                            ),
                            if (_selectedNetworkLabel != null) ...[
                              Divider(color: isDark ? theme.dividerColor : Colors.grey.shade200, height: 20),
                              _buildSummaryRow(
                                'Network',
                                _selectedNetworkLabel!,
                                icon: Icons.hub_outlined,
                                theme: theme,
                              ),
                            ],
                            Divider(color: isDark ? theme.dividerColor : Colors.grey.shade200, height: 20),
                            _buildSummaryRow(
                              'You Receive',
                              _youReceive > 0
                                  ? '${_youReceive.toStringAsFixed(6)} ${_selectedCoin ?? ''}'
                                  : '0.000000 ${_selectedCoin ?? 'Crypto'}',
                              icon: Icons.arrow_downward_rounded,
                              isHighlighted: true,
                              theme: theme,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info tip
                      ModernFormWidgets.buildInfoCard(
                        message: 'Crypto will be sent to the wallet address you provide. Naira will be deducted from your wallet balance. Blockchain delivery may take 3-60 minutes.',
                        icon: Icons.info_outline_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 24),

                      // Buy Button
                      ModernFormWidgets.buildPrimaryButton(
                        label: 'Receive ${_selectedCoin ?? 'Crypto'}',
                        onPressed: _proceedToPin,
                        isLoading: _isLoading,
                        backgroundColor: AppColors.success,
                        icon: Icons.arrow_downward_rounded,
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {
    IconData? icon,
    bool isHighlighted = false,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isHighlighted ? AppColors.success : AppColors.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 14,
              color: isHighlighted ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? theme.textTheme.bodySmall?.color : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlighted ? 15 : 13,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
            color: isHighlighted 
                ? (isDark ? AppColors.success : AppColors.success) 
                : theme.textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }
}
