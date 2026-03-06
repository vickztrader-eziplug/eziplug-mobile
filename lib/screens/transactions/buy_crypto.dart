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
import '../reusable/receipt_screen.dart';

class BuyCryptoScreen extends StatefulWidget {
  final String cryptoName;
  final String cryptoId;
  const BuyCryptoScreen({super.key, required this.cryptoName, required this.cryptoId});

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
  List<Map<String, dynamic>> _coins = [];
  bool _isLoadingCoins = true;

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
    _fetchCoins();
    _amountController.addListener(_calculateYouReceive);
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

  Future<void> _fetchCoins() async {
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

        if (mounted) {
          setState(() {
            _coins = coinsList.map<Map<String, dynamic>>((coin) => {
              'id': coin['id']?.toString() ?? '',
              'symbol': (coin['symbol'] ?? coin['name'] ?? '').toString().toUpperCase(),
              'name': coin['name'] ?? coin['symbol'] ?? '',
              'buy_rate_ngn': double.tryParse(coin['buy_rate_ngn']?.toString() ?? '0') ?? 0.0,
            }).toList();
            _isLoadingCoins = false;

            // Auto-select coin if matching (prefer id, fallback to symbol)
            Map<String, dynamic>? match;
            if (widget.cryptoId.isNotEmpty) {
              match = _coins.cast<Map<String, dynamic>?>().firstWhere(
                (c) => c!['id'] == widget.cryptoId,
                orElse: () => null,
              );
            }
            match ??= _coins.cast<Map<String, dynamic>?>().firstWhere(
              (c) => c!['symbol'] == widget.cryptoName.toUpperCase(),
              orElse: () => null,
            );
            if (match != null) {
              _selectedCoin = match['symbol'];
              _selectedCoinId = match['id'];
              _currentRate = match['buy_rate_ngn'] ?? 0.0;
              _isLoadingRate = false;
            }
          });
        }
      } else {
        _loadFallbackCoins();
      }
    } catch (e) {
      _loadFallbackCoins();
    }
  }

  void _loadFallbackCoins() {
    if (mounted) {
      setState(() {
        _coins = [
          {'id': '1', 'symbol': 'BTC', 'name': 'Bitcoin', 'buy_rate_ngn': 0.0},
          {'id': '2', 'symbol': 'USDT', 'name': 'Tether', 'buy_rate_ngn': 0.0},
        ];
        _isLoadingCoins = false;
        _isLoadingRate = false;
      });
    }
  }

  void _onCoinSelected(String coinId) {
    final coin = _coins.firstWhere(
      (c) => c['id'] == coinId,
      orElse: () => {},
    );
    setState(() {
      _selectedCoin = coin['symbol']?.toString();
      _selectedCoinId = coinId;
      _currentRate = coin['buy_rate_ngn'] ?? 0.0;
      _isLoadingRate = false;
    });
    _calculateYouReceive();
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

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              title: 'Purchase Successful',
              subtitle: 'Your $_selectedCoin purchase has been submitted',
              details: [
                ReceiptDetail(
                  label: 'Transaction ID',
                  value: responseData['transaction_id']?.toString() ??
                      responseData['reference']?.toString() ?? 'N/A',
                ),
                ReceiptDetail(label: 'Crypto', value: _selectedCoin ?? widget.cryptoName),
                ReceiptDetail(
                  label: 'Amount Paid',
                  value: '₦${_formatBalance(amountNaira)}',
                ),
                ReceiptDetail(
                  label: 'You Receive',
                  value: '${_youReceive.toStringAsFixed(6)} $_selectedCoin',
                ),
                ReceiptDetail(
                  label: 'Rate',
                  value: '₦${_formatBalance(_currentRate)}/$_selectedCoin',
                ),
                ReceiptDetail(
                  label: 'Wallet Address',
                  value: _walletAddressController.text,
                ),
                ReceiptDetail(
                  label: 'Date',
                  value: DateTime.now().toString().split('.')[0],
                ),
              ],
            ),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              // Modern Gradient Header
              ModernFormWidgets.buildGradientHeader(
                context: context,
                title: 'Buy ${_selectedCoin ?? widget.cryptoName}',
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
                      // Coin Selection
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Select Coin',
                              icon: Icons.currency_bitcoin_rounded,
                              iconColor: AppColors.cryptoColor,
                            ),
                            const SizedBox(height: 12),
                            _isLoadingCoins
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _coins.map((coin) {
                                      final coinId = coin['id'] as String;
                                      final name = coin['name'] as String;
                                      final symbol = coin['symbol'] as String;
                                      final isSelected = _selectedCoinId == coinId;
                                      return ModernFormWidgets.buildSelectableChip(
                                        label: '$name ($symbol)',
                                        isSelected: isSelected,
                                        onTap: () => _onCoinSelected(coinId),
                                        selectedColor: AppColors.primary,
                                      );
                                    }).toList(),
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

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
                              hintText: 'Paste your external wallet address',
                              prefixIcon: Icons.link_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Rate & Summary Card
                      ModernFormWidgets.buildFormCard(
                        backgroundColor: AppColors.primary.withOpacity(0.04),
                        child: Column(
                          children: [
                            _buildSummaryRow(
                              'Rate',
                              _currentRate > 0
                                  ? '₦${_formatBalance(_currentRate)} / 1 ${_selectedCoin ?? 'Crypto'}'
                                  : 'Select a coin',
                              icon: Icons.trending_up_rounded,
                            ),
                            Divider(color: Colors.grey.shade200, height: 20),
                            _buildSummaryRow(
                              'You Receive',
                              _youReceive > 0
                                  ? '${_youReceive.toStringAsFixed(6)} ${_selectedCoin ?? ''}'
                                  : '0.000000 ${_selectedCoin ?? 'Crypto'}',
                              icon: Icons.arrow_downward_rounded,
                              isHighlighted: true,
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
                        label: 'Buy ${_selectedCoin ?? 'Crypto'}',
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
  }) {
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
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlighted ? 15 : 13,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
            color: isHighlighted ? AppColors.success : AppColors.textColor,
          ),
        ),
      ],
    );
  }
}
