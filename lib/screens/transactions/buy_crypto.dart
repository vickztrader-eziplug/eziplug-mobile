import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/auth_service.dart';
import '../reusable/pin_entry_screen.dart';
import '../reusable/receipt_screen.dart';

class BuyCryptoScreen extends StatefulWidget {
  final String cryptoName;
  const BuyCryptoScreen({super.key, required this.cryptoName});

  @override
  State<BuyCryptoScreen> createState() => _BuyCryptoScreenState();
}

class _BuyCryptoScreenState extends State<BuyCryptoScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _walletAddressController =
      TextEditingController();
  bool _isLoading = false;
  final double _currentRate = 230.0;
  double _youReceive = 0.0;

  String? _selectedCoin;

  List<String>? get _coins => ['BTC', 'USDT'];

  @override
  void dispose() {
    _amountController.dispose();
    _walletAddressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();
    // _fetchCurrentRate(); // TODO: Uncomment when API is ready
    _amountController.addListener(_calculateYouReceive);
  }

  // Improved authentication check that doesn't force logout
  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();

    // Only redirect if definitely not authenticated and the widget is still mounted
    if ((token == null || token.isEmpty) && mounted) {
      // Use push instead of pushReplacement to allow going back
      // Navigator.pushNamed(context, '/login');
      print('not authenticated: $token');
    }
  }

  void _calculateYouReceive() {
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    if (mounted) {
      setState(() {
        _youReceive = amount * _currentRate;
      });
    }
  }

  Future<void> _proceedToPin() async {
    // Validation
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

    if (_walletAddressController.text.isEmpty) {
      _showSnackBar('Please enter wallet address', Colors.red);
      return;
    }

    // Check auth right before proceeding to PIN
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    print('token: $token');

    if (token == null || token.isEmpty) {
      _showSnackBar('Please login to continue', Colors.red);
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Navigate to PIN screen
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinEntryScreen(
          title: 'Confirm Purchase',
          subtitle: 'Enter your 4 digit PIN to buy $_selectedCoin',
          onPinComplete: (pin) => _buyCrypto(pin),
          onForgotPin: () {
            Navigator.pop(context);
            _showSnackBar('Contact support to reset PIN', Colors.orange);
          },
        ),
      ),
    );
  }

  Future<void> _buyCrypto(String pin) async {
    setState(() => _isLoading = true); // Show loader

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.post(
        Uri.parse(Constants.buyCryptoUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'coin': _selectedCoin ?? widget.cryptoName,
          'crypto_type':
              _selectedCoin?.toLowerCase() ?? widget.cryptoName.toLowerCase(),
          'amount': _amountController.text,
          'to_address': _walletAddressController.text,
          'rate': _currentRate.toString(),
          'total_received': _youReceive.toString(),
          'pin': pin,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (!mounted) return;
      print('responseData: $responseData');

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context); // Close PIN screen

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              title: 'Purchase Successful',
              subtitle: 'Your ${widget.cryptoName} purchase has been completed',
              details: [
                ReceiptDetail(
                  label: 'Transaction ID',
                  value: responseData['transaction_id'] ?? 'N/A',
                ),
                ReceiptDetail(label: 'Crypto Type', value: widget.cryptoName),
                ReceiptDetail(
                  label: 'Amount',
                  value: '\$${_amountController.text}',
                ),
                ReceiptDetail(
                  label: 'Rate',
                  value: '₦${_currentRate.toStringAsFixed(2)}',
                ),
                ReceiptDetail(
                  label: 'You Receive',
                  value: '₦${_youReceive.toStringAsFixed(2)}',
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
        Navigator.pop(context); // Close PIN screen
        _showSnackBar('Session expired. Please login again', Colors.red);
        await authService.logout();
      } else if (response.statusCode == 400 &&
          responseData['message']?.contains('PIN') == true) {
        throw Exception(responseData['message'] ?? 'Invalid PIN');
      } else {
        Navigator.pop(context);
        _showSnackBar(
          responseData['message'] ??
              'Failed to buy ${_selectedCoin ?? widget.cryptoName}',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
      rethrow;
    } finally {
      if (mounted) setState(() => _isLoading = false); // Hide loader
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    // Use ToastHelper for consistent top-positioned toasts
    ToastHelper.showSnackBar(context, message, color);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
              ),
            // Header Section
            Container(
              width: double.infinity,
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              'Buy ${widget.cryptoName}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Section with curved top
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Coin Dropdown
                      _buildLabel('Coin'),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        hint: 'Select coin',
                        value: _selectedCoin,
                        items: _coins ?? [],
                        onChanged: (value) {
                          setState(() => _selectedCoin = value);
                          // TODO: Fetch rate for selected coin when API is ready
                        },
                      ),
                      const SizedBox(height: 20),

                      // Enter Amount
                      _buildLabel('Enter Amount'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _amountController,
                        hintText: '\$0.00',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),

                      // Wallet Address
                      _buildLabel('Wallet Address'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _walletAddressController,
                        hintText:
                            'Enter your ${widget.cryptoName} wallet address',
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 20),

                      // Credit Rate
                      _buildLabel('Credit Rate'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: AppColors.lightGrey,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current rate',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textColor.withOpacity(0.5),
                              ),
                            ),
                            Text(
                              '₦${_currentRate.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // You Receive
                      _buildLabel('You Receive'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.lightGrey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${_youReceive.toStringAsFixed(4)} ${_selectedCoin ?? 'Crypto'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Buy Crypto Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _proceedToPin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            disabledBackgroundColor: AppColors.lightGrey,
                          ),
                          child: Text(
                            'Buy ${_selectedCoin ?? 'Crypto'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textColor,
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.lightGrey, width: 2),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(
          hint,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textColor.withOpacity(0.5),
          ),
        ),
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down),
        items: items.map((String item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.lightGrey, width: 2),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: AppColors.textColor),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 14,
            color: AppColors.textColor.withOpacity(0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
