import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../services/auth_service.dart';
import 'crypto_sell_success_screen.dart';

class SellCryptoScreen extends StatefulWidget {
  final String cryptoName;
  final String cryptoId;
  const SellCryptoScreen({super.key, required this.cryptoName, required this.cryptoId});

  @override
  State<SellCryptoScreen> createState() => _SellCryptoScreenState();
}

class _SellCryptoScreenState extends State<SellCryptoScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingWallet = true;
  bool _isLoadingCoins = true;
  bool _isGeneratingWallet = false;
  double _walletNaira = 0.0;
  double _currentRate = 0.0;

  String? _selectedCoin;
  String? _selectedCoinId;
  List<Map<String, dynamic>> _coins = [];

  String? _walletAddress;
  String? _qrCodeData;
  int? _tradeId;
  Timer? _expiryTimer;
  Timer? _pollTimer;
  int _remainingSeconds = 900; // 15 minutes

  late AnimationController _timerPulseController;

  @override
  void initState() {
    super.initState();
    _timerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    // Initialize with cached balance immediately so it doesn't show 0
    final authService = Provider.of<AuthService>(context, listen: false);
    _walletNaira = authService.walletNaira;
    if (_walletNaira > 0) {
      _isLoadingWallet = false;
    }
    _fetchWalletBalance();
    _fetchCoins();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _expiryTimer?.cancel();
    _pollTimer?.cancel();
    _timerPulseController.dispose();
    super.dispose();
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
              'sell_rate_ngn': double.tryParse(coin['sell_rate_ngn']?.toString() ?? '0') ?? 0.0,
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
              _currentRate = match['sell_rate_ngn'] ?? 0.0;
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
          {'id': '1', 'symbol': 'BTC', 'name': 'Bitcoin', 'sell_rate_ngn': 0.0},
          {'id': '2', 'symbol': 'USDT', 'name': 'Tether', 'sell_rate_ngn': 0.0},
        ];
        _isLoadingCoins = false;
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
      _currentRate = coin['sell_rate_ngn'] ?? 0.0;
      // Reset wallet address when coin changes
      _walletAddress = null;
      _qrCodeData = null;
      _expiryTimer?.cancel();
    });
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    setState(() => _remainingSeconds = 900);
    _timerPulseController.repeat(reverse: true);

    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _timerPulseController.stop();
        _pollTimer?.cancel();
        _showSnackBar('Address has expired. Please generate a new one.', Colors.orange);
        setState(() {
          _walletAddress = null;
          _qrCodeData = null;
          _tradeId = null;
        });
      }
    });
  }

  void _startDepositPolling() {
    _pollTimer?.cancel();
    if (_tradeId == null) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted || _tradeId == null) {
        timer.cancel();
        return;
      }

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final token = await authService.getToken();
        if (token == null) return;

        final response = await http.get(
          Uri.parse('${Constants.cryptoTradeStatusUrl}/$_tradeId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final tradeStatus = data['data']?['trade_status'] ?? '';

          if (tradeStatus == 'confirmed' || tradeStatus == 'completed') {
            timer.cancel();
            _expiryTimer?.cancel();
            _timerPulseController.stop();

            final nairaAmount = data['data']?['naira_equivalent'];
            final confirmedAmount = data['data']?['confirmed_amount_crypto'];

            _showSuccessDialog(
              confirmedAmount?.toString() ?? _amountController.text,
              nairaAmount?.toString() ?? '0',
            );
          }
        }
      } catch (_) {
        // Silently ignore polling errors
      }
    });
  }

  void _showSuccessDialog(String cryptoAmount, String nairaAmount) {
    if (!mounted) return;

    // Navigate to full-screen success page
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CryptoSellSuccessScreen(
          cryptoAmount: cryptoAmount,
          coinSymbol: _selectedCoin ?? widget.cryptoName,
          nairaAmount: nairaAmount,
          depositAddress: _walletAddress,
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Color _getTimerColor() {
    if (_remainingSeconds > 600) return AppColors.success;
    if (_remainingSeconds > 300) return AppColors.warning;
    return AppColors.error;
  }

  Future<void> _generateWalletAddress() async {
    if (_selectedCoin == null) {
      _showSnackBar('Please select a coin', Colors.red);
      return;
    }

    if (_amountController.text.isEmpty) {
      _showSnackBar('Please enter amount', Colors.red);
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount', Colors.red);
      return;
    }

    setState(() => _isGeneratingWallet = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        _showSnackBar('Please login to continue', Colors.red);
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Single API call to the new sell endpoint
      final response = await http.post(
        Uri.parse(Constants.sellCryptoUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'crypto_id': _selectedCoinId ?? widget.cryptoId,
          'amount_crypto': amount,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse address from multiple possible response structures
        final resultsData = responseData['results']?['data'];
        final depositAddress = responseData['deposit_address'] ??
            resultsData?['deposit_address'] ??
            responseData['data']?['deposit_address'] ??
            responseData['address'];
        final qrCode = responseData['qr_code'] ??
            resultsData?['qr_code'];
        final expiresAtStr = responseData['expires_at'] ??
            resultsData?['expires_at'];

        setState(() {
          _walletAddress = depositAddress;
          _qrCodeData = _walletAddress;
          _tradeId = resultsData?['trade_id'] ??
              responseData['trade_id'];

          // Use backend-provided expiry or default to 15 minutes
          if (expiresAtStr != null) {
            final expiresAt = DateTime.tryParse(expiresAtStr.toString());
            if (expiresAt != null) {
              _remainingSeconds = expiresAt.difference(DateTime.now()).inSeconds;
              if (_remainingSeconds < 0) _remainingSeconds = 0;
            }
          }
        });
        _startExpiryTimer();
        _startDepositPolling();
        _showSnackBar('Deposit address generated. Send crypto to this address.', Colors.green);
      } else if (response.statusCode == 401) {
        _showSnackBar('Session expired. Please login again', Colors.red);
        await authService.logout();
      } else {
        throw Exception(
          responseData['message'] ?? 'Failed to generate deposit address',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(ErrorHandler.getUserFriendlyMessage(e), Colors.red);
    } finally {
      if (mounted) setState(() => _isGeneratingWallet = false);
    }
  }

  void _copyToClipboard() {
    if (_walletAddress != null) {
      Clipboard.setData(ClipboardData(text: _walletAddress!));
      HapticFeedback.mediumImpact();
      _showSnackBar('Address copied to clipboard', Colors.green);
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
                title: 'Sell ${_selectedCoin ?? widget.cryptoName}',
                subtitle: 'Send crypto, receive Naira',
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
                              'Amount (Crypto)',
                              icon: Icons.payments_outlined,
                              iconColor: AppColors.primary,
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildTextField(
                              controller: _amountController,
                              hintText: 'Enter crypto amount to sell',
                              prefixIcon: Icons.money,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Rate Display
                      if (_currentRate > 0)
                        ModernFormWidgets.buildFormCard(
                          backgroundColor: AppColors.primary.withOpacity(0.04),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.trending_up_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sell Rate',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₦${_formatBalance(_currentRate)} = 1 ${_selectedCoin ?? 'Crypto'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_currentRate > 0) const SizedBox(height: 16),

                      // Generate Address or Show Address
                      if (_walletAddress == null)
                        ModernFormWidgets.buildPrimaryButton(
                          label: 'Generate Deposit Address',
                          onPressed: _generateWalletAddress,
                          isLoading: _isGeneratingWallet,
                          backgroundColor: AppColors.primary,
                          icon: Icons.qr_code_rounded,
                        ),

                      // Wallet Address Display Section
                      if (_walletAddress != null) ...[
                        _buildDepositAddressCard(),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 16),

                      // Info tip
                      ModernFormWidgets.buildInfoCard(
                        message: _walletAddress != null
                            ? 'Send the exact amount to the address above. Your Naira wallet will be credited after blockchain confirmation (3-60 minutes).'
                            : 'Generate a deposit address, then send crypto from your external wallet (Trust Wallet, Binance, etc.) to receive Naira credit.',
                        icon: Icons.info_outline_rounded,
                        color: AppColors.primary,
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

  Widget _buildDepositAddressCard() {
    final timerColor = _getTimerColor();

    return ModernFormWidgets.buildFormCard(
      child: Column(
        children: [
          // Timer Banner
          AnimatedBuilder(
            animation: _timerPulseController,
            builder: (context, child) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      timerColor.withOpacity(0.1 + _timerPulseController.value * 0.05),
                      timerColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: timerColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_rounded, color: timerColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Expires in ',
                      style: TextStyle(
                        fontSize: 12,
                        color: timerColor.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: timerColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Scan to send ${_selectedCoin ?? 'crypto'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$_qrCodeData',
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.background,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_rounded, size: 64, color: AppColors.primary),
                              SizedBox(height: 8),
                              Text(
                                'QR Code',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Wallet Address
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _walletAddress!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _copyToClipboard,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Payment Instructions
          Text(
            'Send payment within 15 minutes',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Regenerate Button
          TextButton.icon(
            onPressed: _generateWalletAddress,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text(
              'Generate New Address',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
