import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../services/auth_service.dart';

class RateCalculatorScreen extends StatefulWidget {
  const RateCalculatorScreen({super.key});

  @override
  State<RateCalculatorScreen> createState() => _RateCalculatorScreenState();
}

class _RateCalculatorScreenState extends State<RateCalculatorScreen> {
  // Use unified app primary color
  static const Color _primaryColor = AppColors.primary;

  bool isGiftcardRate = true;
  String? selectedGiftcard;
  String? selectedCoin;

  final TextEditingController rateController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController totalController = TextEditingController(
    text: '₦0.00',
  );
  final TextEditingController cryptoRateController = TextEditingController(
    text: '\$0.00',
  );
  final TextEditingController cryptoAmountController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController cryptoAmountInputController =
      TextEditingController();

  bool _isLoadingGiftcards = false;
  bool _isLoadingCrypto = false;

  List<Map<String, dynamic>> _giftcards = [];
  List<Map<String, dynamic>> _cryptos = [];

  Map<String, double> _giftcardRates = {};
  Map<String, double> _cryptoRates = {};

  // Default rates as fallback
  final List<Map<String, dynamic>> _defaultGiftcards = [
    {'id': '1', 'name': 'Amazon', 'rate': 850.00},
    {'id': '2', 'name': 'Apple iTunes', 'rate': 820.00},
    {'id': '3', 'name': 'Google Play', 'rate': 800.00},
    {'id': '4', 'name': 'Steam Wallet', 'rate': 780.00},
    {'id': '5', 'name': 'PlayStation Store', 'rate': 790.00},
    {'id': '6', 'name': 'Xbox Gift Card', 'rate': 790.00},
    {'id': '7', 'name': 'Netflix', 'rate': 810.00},
    {'id': '8', 'name': 'Walmart', 'rate': 770.00},
    {'id': '9', 'name': 'Vanilla Visa', 'rate': 760.00},
    {'id': '10', 'name': 'Sephora', 'rate': 750.00},
  ];

  final List<Map<String, dynamic>> _defaultCryptos = [
    {'id': '1', 'name': 'Bitcoin', 'symbol': 'BTC', 'rate': 65000.00},
    {'id': '3', 'name': 'Tether', 'symbol': 'USDT', 'rate': 1.00},
  ];

  @override
  void initState() {
    super.initState();
    // Load default rates first, then fetch from API
    _loadDefaultRates();
    _fetchGiftcardRates();
    _fetchCryptoRates();
  }

  void _loadDefaultRates() {
    _giftcards = List.from(_defaultGiftcards);
    _cryptos = List.from(_defaultCryptos);

    for (var card in _giftcards) {
      _giftcardRates[card['name']] = card['rate'];
    }

    for (var crypto in _cryptos) {
      _cryptoRates[crypto['name']] = crypto['rate'];
    }
  }

  @override
  void dispose() {
    rateController.dispose();
    amountController.dispose();
    totalController.dispose();
    cryptoRateController.dispose();
    cryptoAmountController.dispose();
    cryptoAmountInputController.dispose();
    super.dispose();
  }

  Future<void> _fetchGiftcardRates() async {
    // Only show loading if we don't have rates yet
    if (_giftcards.isEmpty) {
      setState(() => _isLoadingGiftcards = true);
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        if (_giftcards.isEmpty) {
          _setDefaultGiftcardRates();
        }
        return;
      }

      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/giftcard/rates'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Giftcard rates response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          final ratesData =
              data['data'] ?? data['results']?['data'] ?? data['rates'] ?? [];

          if (ratesData is List && ratesData.isNotEmpty) {
            setState(() {
              _giftcards = ratesData
                  .map<Map<String, dynamic>>(
                    (item) => {
                      'id': item['id']?.toString() ?? '',
                      'name': item['name'] ?? item['card_name'] ?? '',
                      'rate':
                          double.tryParse(item['rate']?.toString() ?? '0') ??
                          0.0,
                    },
                  )
                  .toList();

              // Build rate map
              _giftcardRates.clear();
              for (var card in _giftcards) {
                _giftcardRates[card['name']] = card['rate'];
              }

              _isLoadingGiftcards = false;
            });
          } else if (_giftcards.isEmpty) {
            // Empty response and no defaults loaded, use defaults
            _setDefaultGiftcardRates();
          } else {
            // Empty response but we have defaults, just stop loading
            setState(() => _isLoadingGiftcards = false);
          }
        }
      } else if (_giftcards.isEmpty) {
        // API error and no rates loaded, use defaults
        _setDefaultGiftcardRates();
      } else {
        // API error but we have rates, just stop loading
        setState(() => _isLoadingGiftcards = false);
      }
    } catch (e) {
      print('Error fetching giftcard rates: $e');
      if (_giftcards.isEmpty) {
        _setDefaultGiftcardRates();
      } else {
        setState(() => _isLoadingGiftcards = false);
      }
    }
  }

  void _setDefaultGiftcardRates() {
    if (mounted) {
      setState(() {
        _giftcards = List.from(_defaultGiftcards);
        _giftcardRates.clear();
        for (var card in _giftcards) {
          _giftcardRates[card['name']] = card['rate'];
        }
        _isLoadingGiftcards = false;
      });
      // Only show message if we're falling back from a failed API call
      if (_giftcards.isNotEmpty) {
        _showSnackBar(
          'Could not fetch live rates. Using default rates.',
          Colors.orange,
        );
      }
    }
  }

  Future<void> _fetchCryptoRates() async {
    // Only show loading if we don't have rates yet
    if (_cryptos.isEmpty) {
      setState(() => _isLoadingCrypto = true);
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        if (_cryptos.isEmpty) {
          _setDefaultCryptoRates();
        }
        return;
      }

      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/crypto/rates'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Crypto rates response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          final ratesData =
              data['data'] ?? data['results']?['data'] ?? data['rates'] ?? [];

          if (ratesData is List && ratesData.isNotEmpty) {
            setState(() {
              _cryptos = ratesData
                  .map<Map<String, dynamic>>(
                    (item) => {
                      'id': item['id']?.toString() ?? '',
                      'name': item['name'] ?? item['coin_name'] ?? '',
                      'symbol': item['symbol'] ?? '',
                      'rate':
                          double.tryParse(item['rate']?.toString() ?? '0') ??
                          0.0,
                    },
                  )
                  .toList();

              // Build rate map
              _cryptoRates.clear();
              for (var crypto in _cryptos) {
                _cryptoRates[crypto['name']] = crypto['rate'];
              }

              _isLoadingCrypto = false;
            });
          } else if (_cryptos.isEmpty) {
            // Empty response and no defaults loaded, use defaults
            _setDefaultCryptoRates();
          } else {
            // Empty response but we have defaults, just stop loading
            setState(() => _isLoadingCrypto = false);
          }
        }
      } else if (_cryptos.isEmpty) {
        // API error and no rates loaded, use defaults
        _setDefaultCryptoRates();
      } else {
        // API error but we have rates, just stop loading
        setState(() => _isLoadingCrypto = false);
      }
    } catch (e) {
      print('Error fetching crypto rates: $e');
      if (_cryptos.isEmpty) {
        _setDefaultCryptoRates();
      } else {
        setState(() => _isLoadingCrypto = false);
      }
    }
  }

  void _setDefaultCryptoRates() {
    if (mounted) {
      setState(() {
        _cryptos = List.from(_defaultCryptos);
        _cryptoRates.clear();
        for (var crypto in _cryptos) {
          _cryptoRates[crypto['name']] = crypto['rate'];
        }
        _isLoadingCrypto = false;
      });
      // Only show message if we're falling back from a failed API call
      if (_cryptos.isNotEmpty) {
        _showSnackBar(
          'Could not fetch live rates. Using default rates.',
          Colors.orange,
        );
      }
    }
  }

  void _calculateGiftcardTotal() {
    final rate = double.tryParse(rateController.text) ?? 0;
    final amount = double.tryParse(amountController.text) ?? 0;
    final total = rate * amount;
    setState(() {
      totalController.text = '₦${_formatAmount(total)}';
    });
  }

  // === Crypto calculation ===
  void _calculateCryptoAmount() {
    final selectedRate = _cryptoRates[selectedCoin] ?? 0;
    final amount = double.tryParse(cryptoAmountInputController.text) ?? 0;

    if (selectedRate > 0) {
      final cryptoValue = amount / selectedRate;
      final symbol = _cryptos.firstWhere(
        (c) => c['name'] == selectedCoin,
        orElse: () => {'symbol': ''},
      )['symbol'];

      setState(() {
        cryptoAmountController.text =
            '${cryptoValue.toStringAsFixed(8)} $symbol';
      });
    }
  }

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: _primaryColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // Modern Gradient Header
            ModernFormWidgets.buildGradientHeader(
              context: context,
              title: 'Rate Calculator',
              subtitle: 'Calculate giftcard & crypto rates',
              primaryColor: _primaryColor,
            ),

            // Toggle Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: ModernFormWidgets.buildFormCard(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildToggleTab(
                        'Giftcard Rate',
                        Icons.card_giftcard,
                        isGiftcardRate,
                        () => setState(() => isGiftcardRate = true),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildToggleTab(
                        'Crypto Rate',
                        Icons.currency_bitcoin,
                        !isGiftcardRate,
                        () => setState(() => isGiftcardRate = false),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: isGiftcardRate
                    ? _buildGiftcardRateContent()
                    : _buildCryptoRateContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTab(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textColor.withOpacity(0.5),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textColor.withOpacity(0.6),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Giftcard Rate Section =====
  Widget _buildGiftcardRateContent() {
    if (_isLoadingGiftcards) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(60),
          child: Column(
            children: [
              const CircularProgressIndicator(
                color: _primaryColor,
                strokeWidth: 2,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading giftcard rates...',
                style: TextStyle(
                  color: AppColors.textColor.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info Card
        ModernFormWidgets.buildInfoCard(
          message: 'Select a gift card and enter the amount to calculate your payout in Naira.',
          icon: Icons.info_outline,
          color: _primaryColor,
        ),
        const SizedBox(height: 20),

        // Form Card
        ModernFormWidgets.buildFormCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModernFormWidgets.buildDropdown<String>(
                label: 'Select Giftcard',
                hint: 'Choose a gift card',
                value: selectedGiftcard,
                items: _giftcards.map((g) => g['name'] as String).toList(),
                getLabel: (item) => item,
                onChanged: (v) {
                  setState(() {
                    selectedGiftcard = v;
                    final rate = _giftcardRates[v]?.toStringAsFixed(2) ?? "0.00";
                    rateController.text = rate;
                    _calculateGiftcardTotal();
                  });
                },
                prefixIcon: Icons.card_giftcard,
              ),
              const SizedBox(height: 20),

              ModernFormWidgets.buildSectionLabel(
                'Rate (₦ per \$1)',
                icon: Icons.monetization_on_outlined,
                iconColor: _primaryColor,
              ),
              const SizedBox(height: 10),
              _buildReadOnlyField(
                controller: rateController,
                placeholder: 'Rate per dollar',
              ),
              const SizedBox(height: 20),

              ModernFormWidgets.buildTextField(
                controller: amountController,
                hintText: 'Enter amount in USD',
                label: 'Amount (\$)',
                prefixIcon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _calculateGiftcardTotal(),
              ),
              const SizedBox(height: 24),

              // Result Card
              ModernFormWidgets.buildSectionLabel(
                'You will receive',
                icon: Icons.account_balance_wallet_outlined,
                iconColor: _primaryColor,
              ),
              const SizedBox(height: 10),
              _buildResultCard(totalController.text),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Calculate Button
        ModernFormWidgets.buildPrimaryButton(
          label: 'Calculate',
          onPressed: () {
            if (selectedGiftcard == null) {
              _showSnackBar('Please select a giftcard', Colors.red);
              return;
            }
            if (amountController.text.isEmpty) {
              _showSnackBar('Please enter an amount', Colors.red);
              return;
            }
            _calculateGiftcardTotal();
          },
          backgroundColor: _primaryColor,
          icon: Icons.calculate_outlined,
        ),

        const SizedBox(height: 16),

        // Refresh Button
        Center(
          child: TextButton.icon(
            onPressed: () {
              _fetchGiftcardRates();
              _showSnackBar('Refreshing rates...', _primaryColor);
            },
            icon: const Icon(Icons.refresh, size: 18, color: _primaryColor),
            label: const Text(
              'Refresh Rates',
              style: TextStyle(color: _primaryColor, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // ===== Crypto Rate Section =====
  Widget _buildCryptoRateContent() {
    if (_isLoadingCrypto) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(60),
          child: Column(
            children: [
              const CircularProgressIndicator(
                color: _primaryColor,
                strokeWidth: 2,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading crypto rates...',
                style: TextStyle(
                  color: AppColors.textColor.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info Card
        ModernFormWidgets.buildInfoCard(
          message: 'Select a cryptocurrency and enter the USD amount to see the equivalent crypto value.',
          icon: Icons.info_outline,
          color: _primaryColor,
        ),
        const SizedBox(height: 20),

        // Form Card
        ModernFormWidgets.buildFormCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModernFormWidgets.buildDropdown<String>(
                label: 'Select Cryptocurrency',
                hint: 'Choose a coin',
                value: selectedCoin,
                items: _cryptos.map((c) => c['name'] as String).toList(),
                getLabel: (item) => item,
                onChanged: (v) {
                  setState(() {
                    selectedCoin = v;
                    cryptoRateController.text =
                        '\$${_cryptoRates[v]?.toStringAsFixed(2) ?? '0.00'}';
                    _calculateCryptoAmount();
                  });
                },
                prefixIcon: Icons.currency_bitcoin,
              ),
              const SizedBox(height: 20),

              ModernFormWidgets.buildSectionLabel(
                'Current Rate (USD)',
                icon: Icons.show_chart,
                iconColor: _primaryColor,
              ),
              const SizedBox(height: 10),
              _buildReadOnlyField(
                controller: cryptoRateController,
                placeholder: 'Rate in USD',
              ),
              const SizedBox(height: 20),

              ModernFormWidgets.buildTextField(
                controller: cryptoAmountInputController,
                hintText: 'Enter amount in USD',
                label: 'Amount (\$)',
                prefixIcon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _calculateCryptoAmount(),
              ),
              const SizedBox(height: 24),

              // Result Card
              ModernFormWidgets.buildSectionLabel(
                'Crypto Amount',
                icon: Icons.currency_exchange,
                iconColor: _primaryColor,
              ),
              const SizedBox(height: 10),
              _buildResultCard(cryptoAmountController.text),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Calculate Button
        ModernFormWidgets.buildPrimaryButton(
          label: 'Calculate',
          onPressed: () {
            if (selectedCoin == null) {
              _showSnackBar('Please select a coin', Colors.red);
              return;
            }
            if (cryptoAmountInputController.text.isEmpty) {
              _showSnackBar('Please enter an amount', Colors.red);
              return;
            }
            _calculateCryptoAmount();
          },
          backgroundColor: _primaryColor,
          icon: Icons.calculate_outlined,
        ),

        const SizedBox(height: 16),

        // Refresh Button
        Center(
          child: TextButton.icon(
            onPressed: () {
              _fetchCryptoRates();
              _showSnackBar('Refreshing rates...', _primaryColor);
            },
            icon: const Icon(Icons.refresh, size: 18, color: _primaryColor),
            label: const Text(
              'Refresh Rates',
              style: TextStyle(color: _primaryColor, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String placeholder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 18,
            color: _primaryColor.withOpacity(0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              controller.text.isNotEmpty ? controller.text : placeholder,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: controller.text.isNotEmpty
                    ? AppColors.textColor
                    : AppColors.textColor.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryColor.withOpacity(0.15),
            _primaryColor.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet,
            size: 32,
            color: _primaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
