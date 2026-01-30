import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/auth_service.dart';

class SellCryptoScreen extends StatefulWidget {
  final String cryptoName;
  const SellCryptoScreen({super.key, required this.cryptoName});

  @override
  State<SellCryptoScreen> createState() => _SellCryptoScreenState();
}

class _SellCryptoScreenState extends State<SellCryptoScreen> {
  String? _selectedWallet;
  final TextEditingController _amountController = TextEditingController();
  final List<String> _wallets = ['btc', 'usdt'];

  String? _walletAddress;
  String? _qrCodeData;
  bool _isLoading = false;
  bool _isGeneratingWallet = false;
  double _conversionRate = 1500.00; // Temporary rate
  Timer? _expiryTimer;
  int _remainingSeconds = 900; // 15 minutes in seconds

  @override
  void dispose() {
    _amountController.dispose();
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();

    if ((token == null || token.isEmpty) && mounted) {
      print('not authenticated: $token');
    }
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    setState(() {
      _remainingSeconds = 900; // Reset to 15 minutes
    });

    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _showSnackBar(
          'Wallet address has expired. Please generate a new one.',
          Colors.orange,
        );
        setState(() {
          _walletAddress = null;
          _qrCodeData = null;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _generateWalletAddress() async {
    // Validation
    if (_selectedWallet == null) {
      _showSnackBar('Please select a wallet', Colors.red);
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
        // ignore: use_build_context_synchronously
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Step 1: Create wallet
      final createWalletResponse = await http.post(
        Uri.parse(Constants.createWalletUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'coin': widget.cryptoName.toLowerCase()}),
      );

      if (createWalletResponse.statusCode != 200 &&
          createWalletResponse.statusCode != 201) {
        final errorData = jsonDecode(createWalletResponse.body);
        print('createWalletResponse: $errorData');
        throw Exception(errorData['message'] ?? 'Failed to create wallet');
      }

      // Step 2: Generate deposit address
      final depositResponse = await http.post(
        Uri.parse(Constants.depositCryptoUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'blockchain': widget.cryptoName.toLowerCase()}),
      );

      final depositData = jsonDecode(depositResponse.body);

      if (!mounted) return;
      print('depositData: $depositData');

      if (depositResponse.statusCode == 200 ||
          depositResponse.statusCode == 201) {
        setState(() {
          _walletAddress =
              depositData['address'] ?? depositData['wallet_address'];
          _qrCodeData = _walletAddress;
        });

        // Start expiry countdown
        _startExpiryTimer();

        _showSnackBar('Wallet address generated successfully', Colors.green);
      } else if (depositResponse.statusCode == 401) {
        _showSnackBar('Session expired. Please login again', Colors.red);
        await authService.logout();
      } else {
        throw Exception(
          depositData['message'] ?? 'Failed to generate deposit address',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isGeneratingWallet = false);
    }
  }

  void _copyToClipboard() {
    if (_walletAddress != null) {
      Clipboard.setData(ClipboardData(text: _walletAddress!));
      _showSnackBar('Wallet address copied to clipboard', Colors.green);
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
                              'Sell Crypto - ${widget.cryptoName}',
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
                      // Select Wallet Dropdown
                      _buildLabel('Select Coin'),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        hint: 'Select Coin',
                        value: _selectedWallet,
                        items: _wallets,
                        onChanged: (value) {
                          setState(() => _selectedWallet = value);
                        },
                      ),
                      const SizedBox(height: 20),

                      // Amount TextField
                      _buildLabel('Amount'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _amountController,
                        hintText: 'Enter amount to fund',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),

                      // Conversion Rate
                      _buildLabel('Conversion Rate'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.lightGrey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '₦${_conversionRate.toStringAsFixed(2)} = 1 ${widget.cryptoName}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Generate Wallet Address Button
                      if (_walletAddress == null)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isGeneratingWallet
                                ? null
                                : _generateWalletAddress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.textColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              disabledBackgroundColor: AppColors.lightGrey,
                            ),
                            child: _isGeneratingWallet
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Generate Wallet Address',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                      // Wallet Address Display
                      if (_walletAddress != null) ...[
                        Center(
                          child: Column(
                            children: [
                              // QR Code
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.lightGrey,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Scan QR code',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      width: 150,
                                      height: 150,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Image.network(
                                        'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$_qrCodeData',
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                color: AppColors.lightGrey
                                                    .withOpacity(0.3),
                                                child: const Icon(
                                                  Icons.qr_code,
                                                  size: 80,
                                                  color: AppColors.textColor,
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Wallet Address with Copy
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGrey.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _walletAddress!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.primary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _copyToClipboard,
                                      child: const Icon(
                                        Icons.copy,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Expiry Info
                              Text(
                                'Expires in ${_formatTime(_remainingSeconds)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _remainingSeconds < 300
                                      ? Colors.red
                                      : AppColors.textColor.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Payment should be made within 15 minutes',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textColor.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Regenerate Button
                              TextButton(
                                onPressed: _generateWalletAddress,
                                child: const Text(
                                  'Generate New Address',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
