import 'dart:convert';
import 'package:cashpoint/screens/transactions/paystack_webview.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/api_response.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/auth_service.dart';

class CardDepositScreen extends StatefulWidget {
  const CardDepositScreen({super.key});

  @override
  State<CardDepositScreen> createState() => _CardDepositScreenState();
}

class _CardDepositScreenState extends State<CardDepositScreen> {
  final TextEditingController _amountController = TextEditingController();

  bool _isLoading = false;
  int? _selectedAmount;

  final List<int> _amounts = [
    1000,
    2000,
    5000,
    10000,
    20000,
    50000,
    100000,
    200000,
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();

    if ((token == null || token.isEmpty) && mounted) {
      print('Not authenticated: $token');
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _initiatePayment() async {
    // Get final amount
    int amount =
        _selectedAmount ??
        int.tryParse(_amountController.text.replaceAll(',', '')) ??
        0;

    if (amount < 100) {
      _showSnackBar('Minimum amount is ₦100', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();
      final user = authService.user;

      // Initialize payment on your backend
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/payment/initialize'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': 'NGN',
          'payment_method': 'card',
        }),
      );

      print('📡 Initialize Payment Status: ${response.statusCode}');
      print('📦 Initialize Payment Body: ${response.body}');

      setState(() => _isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        final responseData = getResponseData(result);
        final authorizationUrl = responseData['authorization_url'];
        final reference = responseData['reference'];

        if (authorizationUrl == null || reference == null) {
          _showSnackBar(getResponseMessage(result) ?? 'Failed to initialize payment', Colors.red);
          return;
        }

        // Navigate to Paystack payment page
        if (!mounted) return;
        final paymentResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaystackWebView(
              authorizationUrl: authorizationUrl,
              reference: reference,
            ),
          ),
        );

        // Handle result based on platform
        // Web returns Map with {success: bool, data: ...}
        // Mobile returns bool (true = completed, need to verify)
        if (paymentResult is Map && paymentResult['success'] == true) {
          // Web platform - already verified during polling
          final authService = Provider.of<AuthService>(context, listen: false);
          await authService.refreshUserData();
          final responseData = getResponseData(paymentResult['data']);
          _showSuccessDialog(responseData);
        } else if (paymentResult == true) {
          // Mobile platform - need to verify on backend
          print('✅ WebView returned TRUE - calling _verifyPayment with reference: $reference');
          await _verifyPayment(reference);
        } else if (paymentResult is Map && paymentResult['success'] == false) {
          print('❌ WebView returned error map: $paymentResult');
          _showSnackBar(paymentResult['message'] ?? 'Payment failed', Colors.red);
        } else {
          // Payment was cancelled or returned unexpected value
          print('⚠️ WebView returned unexpected value: $paymentResult (type: ${paymentResult.runtimeType})');
        }
      } else {
        final result = jsonDecode(response.body);
        _showSnackBar(
          getResponseMessage(result) ?? 'Failed to initialize payment',
          Colors.red,
        );
      }
    } catch (e) {
      print('Error initiating payment: $e');
      _showSnackBar('Network error. Please try again later.', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyPayment(String reference) async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/payment/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reference': reference}),
      );

      print('📡 Verify Payment Status: ${response.statusCode}');
      print('📦 Verify Payment Body: ${response.body}');

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (isSuccessResponse(result)) {
          // Update user balance
          await authService.refreshUserData();

          // Get response data for the success dialog
          final responseData = getResponseData(result);
          _showSuccessDialog(responseData);
        } else {
          _showSnackBar(
            getResponseMessage(result) ?? 'Payment verification failed',
            Colors.red,
          );
        }
      } else {
        _showSnackBar('Failed to verify payment', Colors.red);
      }
    } catch (e) {
      print('Error verifying payment: $e');
      _showSnackBar('Network error. Please try again later.', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon and Title
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 32),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Payment Successful!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result['reference'] != null) ...[
                      const Text(
                        'Reference',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result['reference']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (result['amount'] != null) ...[
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₦${result['amount']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (result['balance'] != null) ...[
                      const Text(
                        'New Balance',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₦${result['balance']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // OK Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
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
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    // Use ToastHelper for consistent top-positioned toasts
    ToastHelper.showSnackBar(context, message, color);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Enhanced Header Section
            Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      const Text(
                        'Card Deposit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.credit_card_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),

            // Content Section
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // Amount Input Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF9C27B0).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.payments_outlined,
                                        color: Color(0xFF9C27B0),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Enter Amount',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    prefixText: '₦ ',
                                    prefixStyle: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[400],
                                    ),
                                    hintText: '0.00',
                                    hintStyle: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[300],
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 20,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() => _selectedAmount = null);
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Quick Amount Selection
                          const Text(
                            'Quick Select',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _amounts.map((amount) {
                              final isSelected = _selectedAmount == amount;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedAmount = amount;
                                    _amountController.clear();
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            colors: [
                                              AppColors.primary,
                                              AppColors.primary.withOpacity(0.8),
                                            ],
                                          )
                                        : null,
                                    color: isSelected ? null : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected
                                            ? AppColors.primary.withOpacity(0.3)
                                            : Colors.black.withOpacity(0.04),
                                        blurRadius: isSelected ? 12 : 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '₦${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : Colors.grey[800],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 32),

                          // Info Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFFFF9800).withOpacity(0.1),
                                  const Color(0xFFFF9800).withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFF9800).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9800).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline_rounded,
                                    color: Color(0xFFE65100),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Card Payment Fee',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFFE65100),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'A small processing fee applies to card payments',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Proceed Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _initiatePayment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.lock_outline_rounded, size: 20),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Proceed to Payment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Security Badge
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield_outlined, size: 16, color: Colors.grey[500]),
                                const SizedBox(width: 6),
                                Text(
                                  'Secured by Paystack',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Loading Overlay
                    if (_isLoading)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Processing...',
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
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
            ),
          ],
        ),
      ),
    );
  }
}
