import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../core/widgets/pin_verification_modal.dart';
import '../../services/auth_service.dart';

class GiftUserScreen extends StatefulWidget {
  const GiftUserScreen({Key? key}) : super(key: key);

  @override
  State<GiftUserScreen> createState() => _GiftUserScreenState();
}

class _GiftUserScreenState extends State<GiftUserScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  
  // Use unified app primary color
  static const Color _accentColor = AppColors.primary;

  double _walletNaira = 0.0;
  bool _isLoadingWallet = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
  }

  @override
  void dispose() {
    usernameController.dispose();
    amountController.dispose();
    noteController.dispose();
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
      print('Error fetching wallet: $e');
      if (mounted) {
        setState(() => _isLoadingWallet = false);
      }
    }
  }

  Future<void> _proceedToPin() async {
    // Validation
    if (usernameController.text.isEmpty) {
      _showSnackBar('Please enter recipient username', Colors.red);
      return;
    }

    if (usernameController.text.length < 3) {
      _showSnackBar('Username must be at least 3 characters', Colors.red);
      return;
    }

    if (amountController.text.isEmpty) {
      _showSnackBar('Please enter amount to gift', Colors.red);
      return;
    }

    final amount =
        double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0;

    if (amount <= 0) {
      _showSnackBar('Please enter a valid amount', Colors.red);
      return;
    }

    if (amount > _walletNaira) {
      _showSnackBar('Insufficient balance', Colors.red);
      return;
    }

    // Check auth
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();

    if (token == null || token.isEmpty) {
      _showSnackBar('Please login to continue', Colors.red);
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Show PIN verification modal
    if (!mounted) return;

    final pin = await PinVerificationModal.show(
      context: context,
      title: 'Confirm Gift',
      subtitle: 'Enter your 4-digit PIN to confirm this gift',
      transactionType: 'Gift User',
      recipient: usernameController.text,
      amount: '₦${amount.toStringAsFixed(0)}',
      onForgotPin: () {
        _showSnackBar('Go to Profile > PIN Management to reset your PIN', Colors.orange);
      },
    );

    if (pin != null && pin.length == 4) {
      _processGift(pin);
    }
  }

  Future<void> _processGift(String pin) async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final amount =
          double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0;

      final payload = {
        'username': usernameController.text.trim(),
        'amount': amount,
        'pin': pin,
      };

      print('Gift user payload: $payload');

      final response = await http.post(
        Uri.parse(Constants.gituser),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);
      print('Gift user response: $responseData');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh wallet balance
        _fetchWalletBalance();

        // Show success dialog
        _showSuccessDialog(
          responseData['message'] ?? 'Gift sent successfully',
          amount,
          usernameController.text,
        );

        // Clear inputs
        usernameController.clear();
        amountController.clear();
        noteController.clear();
      } else if (response.statusCode == 401) {
        _showSnackBar('Session expired. Please login again', Colors.red);
        await authService.logout();
      } else if (response.statusCode == 400 &&
          responseData['message']?.toString().contains('PIN') == true) {
        throw Exception(responseData['message'] ?? 'Invalid PIN');
      } else if (response.statusCode == 422) {
        // Handle validation errors
        String errorMessage = 'Validation failed';
        if (responseData['errors'] != null && responseData['errors'] is Map) {
          final errors = responseData['errors'] as Map;
          // Get first error message from errors object
          if (errors.isNotEmpty) {
            final firstField = errors.keys.first;
            final fieldErrors = errors[firstField];
            if (fieldErrors is List && fieldErrors.isNotEmpty) {
              errorMessage = fieldErrors.first.toString();
            }
          }
        } else if (responseData['message'] != null) {
          errorMessage = responseData['message'];
        }
        _showSnackBar(errorMessage, Colors.red);
      } else {
        _showSnackBar(
          responseData['message'] ?? 'Failed to send gift',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
      rethrow;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String message, double amount, String username) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: Colors.green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Gift Sent!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₦${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'to @$username',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    // Use ToastHelper for consistent top-positioned toasts
    ToastHelper.showSnackBar(context, message, color);
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
                title: 'Gift User',
                subtitle: 'Send money to friends & family',
                walletBalance: _walletNaira,
                isLoadingBalance: _isLoadingWallet,
                primaryColor: _accentColor,
              ),
              
              // Content Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      
                      // Info Card
                      ModernFormWidgets.buildInfoCard(
                        message: 'Send money instantly to any Eziplug user. Just enter their username or email and the amount you want to gift.',
                        icon: Icons.card_giftcard,
                        color: _accentColor,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Recipient Input Section
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Recipient Details',
                              icon: Icons.person_outline,
                              iconColor: _accentColor,
                            ),
                            const SizedBox(height: 16),
                            ModernFormWidgets.buildTextField(
                              controller: usernameController,
                              hintText: 'Enter username or email',
                              prefixIcon: Icons.alternate_email,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Amount Section
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Gift Amount',
                              icon: Icons.payments_outlined,
                              iconColor: _accentColor,
                            ),
                            const SizedBox(height: 16),
                            ModernFormWidgets.buildTextField(
                              controller: amountController,
                              hintText: 'Enter amount to gift',
                              prefixIcon: Icons.account_balance_wallet_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              suffixWidget: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: _accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'NGN',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _accentColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Note Section (Optional)
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Add a Note (Optional)',
                              icon: Icons.message_outlined,
                              iconColor: _accentColor,
                            ),
                            const SizedBox(height: 16),
                            ModernFormWidgets.buildTextField(
                              controller: noteController,
                              hintText: 'Write a message to the recipient...',
                              prefixIcon: Icons.edit_note,
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Gift Tips Info Card
                      ModernFormWidgets.buildInfoCard(
                        message: 'Tip: Double-check the recipient\'s username before sending. Gifts are processed instantly and cannot be reversed.',
                        icon: Icons.lightbulb_outline,
                        color: Colors.amber.shade700,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Send Gift Button
                      ModernFormWidgets.buildPrimaryButton(
                        label: 'Send Gift',
                        onPressed: _proceedToPin,
                        isLoading: _isLoading,
                        backgroundColor: _accentColor,
                        icon: Icons.card_giftcard,
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black38,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: _accentColor,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Processing gift...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
