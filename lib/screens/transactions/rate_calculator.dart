import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../services/auth_service.dart';

class RateCalculatorScreen extends StatefulWidget {
  const RateCalculatorScreen({super.key});

  @override
  State<RateCalculatorScreen> createState() => _RateCalculatorScreenState();
}

class _RateCalculatorScreenState extends State<RateCalculatorScreen> {
  bool isGiftcardRate = true;
  String? selectedGiftcard;
  String? selectedCoin;

  final TextEditingController rateController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController totalController = TextEditingController(
    text: 'N0.00',
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
      totalController.text = 'N${total.toStringAsFixed(2)}';
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

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ===== Header =====
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'Rate Calculator',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () {
                      if (isGiftcardRate) {
                        _fetchGiftcardRates();
                      } else {
                        _fetchCryptoRates();
                      }
                      _showSnackBar('Refreshing rates...', AppColors.primary);
                    },
                  ),
                ],
              ),
            ),

            // ===== Toggle Buttons =====
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 40.0,
                vertical: 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      'Giftcard Rate',
                      isGiftcardRate,
                      () => setState(() => isGiftcardRate = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildToggleButton(
                      'Crypto Rate',
                      !isGiftcardRate,
                      () => setState(() => isGiftcardRate = false),
                    ),
                  ),
                ],
              ),
            ),

            // ===== White Content Card =====
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: isGiftcardRate
                      ? _buildGiftcardRateContent()
                      : _buildCryptoRateContent(),
                ),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Select Giftcards"),
        _buildDropdown(
          value: selectedGiftcard,
          items: _giftcards.map((g) => g['name'] as String).toList(),
          hint: "Select gift card",
          onChanged: (v) {
            setState(() {
              selectedGiftcard = v;
              final rate = _giftcardRates[v]?.toStringAsFixed(2) ?? "0.00";
              rateController.text = rate;
              _calculateGiftcardTotal();
            });
          },
        ),
        const SizedBox(height: 16),

        _buildLabel("Rate (₦)"),
        _buildTextField(
          rateController,
          "Rate per dollar",
          readOnly: true,
          isLight: true,
        ),
        const SizedBox(height: 16),

        _buildLabel("Amount (\$)"),
        _buildTextField(
          amountController,
          "Enter amount in USD",
          onChanged: (_) => _calculateGiftcardTotal(),
        ),
        const SizedBox(height: 16),

        _buildLabel("Total (₦)"),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              totalController.text,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        _buildButton("Calculate", () {
          if (selectedGiftcard == null) {
            _showSnackBar('Please select a giftcard', Colors.red);
            return;
          }
          if (amountController.text.isEmpty) {
            _showSnackBar('Please enter an amount', Colors.red);
            return;
          }
          _calculateGiftcardTotal();
        }),
      ],
    );
  }

  // ===== Crypto Rate Section =====
  Widget _buildCryptoRateContent() {
    if (_isLoadingCrypto) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Select Coins"),
        _buildDropdown(
          value: selectedCoin,
          items: _cryptos.map((c) => c['name'] as String).toList(),
          hint: "Select coin",
          onChanged: (v) {
            setState(() {
              selectedCoin = v;
              cryptoRateController.text =
                  '${_cryptoRates[v]?.toStringAsFixed(2) ?? '0.00'}';
              _calculateCryptoAmount();
            });
          },
        ),
        const SizedBox(height: 25),

        _buildLabel("Rate (\$)"),
        _buildTextField(
          cryptoRateController,
          "Rate in USD",
          readOnly: true,
          isLight: true,
        ),
        const SizedBox(height: 25),

        _buildLabel("Amount (\$)"),
        _buildTextField(
          cryptoAmountInputController,
          "Enter amount in USD",
          onChanged: (_) => _calculateCryptoAmount(),
        ),
        const SizedBox(height: 30),

        _buildLabel("Crypto Amount"),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              cryptoAmountController.text,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        _buildButton("Calculate", () {
          if (selectedCoin == null) {
            _showSnackBar('Please select a coin', Colors.red);
            return;
          }
          if (cryptoAmountInputController.text.isEmpty) {
            _showSnackBar('Please enter an amount', Colors.red);
            return;
          }
          _calculateCryptoAmount();
        }),
      ],
    );
  }

  // ===== Reusable Widgets =====

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    ),
  );

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool readOnly = false,
    bool isLight = false,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isLight ? AppColors.light : AppColors.lightGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(5),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(5),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) => SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    ),
  );

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.black87 : Colors.white.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
