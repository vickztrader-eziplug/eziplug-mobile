import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/api_response.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../services/auth_service.dart';
import '../reusable/pin_entry_screen.dart';
import '../reusable/receipt_screen.dart';

class AirtimeSwapScreen extends StatefulWidget {
  const AirtimeSwapScreen({super.key});

  @override
  State<AirtimeSwapScreen> createState() => _AirtimeSwapScreenState();
}

class _AirtimeSwapScreenState extends State<AirtimeSwapScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();

  String? _selectedNetwork;
  String? _selectedNetworkName;
  double _walletNaira = 0.0;
  bool _isLoadingWallet = true;
  bool _isLoading = false;
  double _cashAmount = 0.0;
  int _conversionRate = 85; // Default 85%

  final List<Map<String, dynamic>> _networks = [
    {
      'id': '1',
      'name': 'MTN',
      'color': AppColors.primary,
      'assetPath': 'assets/images/mtn.png',
    },
    {
      'id': '4',
      'name': 'GLO',
      'color': AppColors.primary,
      'assetPath': 'assets/images/glo.png',
    },
    {
      'id': '2',
      'name': 'AIRTEL',
      'color': AppColors.primary,
      'assetPath': 'assets/images/airtel.png',
    },
    {
      'id': '3',
      'name': '9MOBILE',
      'color': AppColors.primary,
      'assetPath': 'assets/images/9mobile.png',
    },
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
    _fetchConversionRate();
    _amountController.addListener(_calculateCashAmount);
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
        Uri.parse('${Constants.baseUrl}/user'),
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

  Future<void> _fetchConversionRate() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/airtime-swap/rate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted && isSuccessResponse(data)) {
          final responseData = getResponseData(data);
          setState(() {
            _conversionRate = responseData['conversion_rate'] ?? 85;
          });
        }
      }
    } catch (e) {
      print('Error fetching conversion rate: $e');
    }
  }

  void _calculateCashAmount() {
    final airtimeAmount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;

    setState(() {
      _cashAmount = (airtimeAmount * _conversionRate) / 100;
    });
  }

  Future<void> _selectContact() async {
    try {
      final permissionGranted = await FlutterContacts.requestPermission();

      if (!permissionGranted) {
        _showSnackBar(
          'Contact permission is required to select contacts',
          Colors.orange,
        );
        return;
      }

      final Contact? contact = await FlutterContacts.openExternalPick();

      if (contact != null) {
        final Contact? fullContact = await FlutterContacts.getContact(
          contact.id,
        );

        if (fullContact != null && fullContact.phones.isNotEmpty) {
          setState(() {
            String phoneNumber = fullContact.phones.first.number.replaceAll(
              RegExp(r'[^\d+]'),
              '',
            );
            _phoneController.text = phoneNumber;
          });
          _showSnackBar('Contact selected successfully', Colors.green);
        } else {
          _showSnackBar('Selected contact has no phone number', Colors.orange);
        }
      }
    } catch (e) {
      print('Error selecting contact: $e');
      _showSnackBar('Failed to select contact', Colors.red);
    }
  }

  Future<void> _proceedToPin() async {
    // Validation
    if (_phoneController.text.isEmpty) {
      _showSnackBar('Please enter phone number', Colors.red);
      return;
    }

    if (_phoneController.text.length != 11) {
      _showSnackBar('Phone number must be 11 digits', Colors.red);
      return;
    }

    if (_selectedNetwork == null) {
      _showSnackBar('Please select a network', Colors.red);
      return;
    }

    if (_amountController.text.isEmpty) {
      _showSnackBar('Please enter airtime amount', Colors.red);
      return;
    }

    final airtimeAmount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;

    if (airtimeAmount < 100) {
      _showSnackBar('Minimum amount is ₦100', Colors.red);
      return;
    }

    if (airtimeAmount > 50000) {
      _showSnackBar('Maximum amount is ₦50,000', Colors.red);
      return;
    }

    if (_cashAmount <= 0) {
      _showSnackBar('Invalid swap amount', Colors.red);
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

    // Navigate to PIN screen
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinEntryScreen(
          title: 'Confirm Swap',
          subtitle: 'Enter your 4 digit PIN to swap airtime',
          onPinComplete: (pin) => _processSwap(pin),
          onForgotPin: () {
            Navigator.pop(context);
            _showSnackBar('Contact support to reset PIN', Colors.orange);
          },
        ),
      ),
    );
  }

  Future<void> _processSwap(String pin) async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final airtimeAmount =
          double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;

      final payload = {
        'phone_number': _phoneController.text,
        'network': _selectedNetwork,
        'airtime_amount': airtimeAmount,
        'account_number': _accountNumberController.text.isNotEmpty
            ? _accountNumberController.text
            : null,
        'account_name': _accountNameController.text.isNotEmpty
            ? _accountNameController.text
            : null,
        'bank_name': _bankNameController.text.isNotEmpty
            ? _bankNameController.text
            : null,
        'pin': pin,
      };

      print('Swap payload: $payload');

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/vtu/airtime-swap/swap'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);
      print('Swap response: $responseData');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context); // Close PIN screen

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              title: 'Swap Request Submitted',
              subtitle: 'Your airtime swap request is pending verification',
              details: [
                ReceiptDetail(
                  label: 'Transaction ID',
                  value: responseData['transaction_id'] ?? 'N/A',
                ),
                ReceiptDetail(
                  label: 'Phone Number',
                  value: _phoneController.text,
                ),
                ReceiptDetail(label: 'Network', value: _selectedNetworkName ?? ''),
                ReceiptDetail(
                  label: 'Airtime Amount',
                  value: '₦${airtimeAmount.toStringAsFixed(2)}',
                ),
                ReceiptDetail(
                  label: 'Conversion Rate',
                  value: '$_conversionRate%',
                ),
                ReceiptDetail(
                  label: 'Expected Cash',
                  value: '₦${_cashAmount.toStringAsFixed(2)}',
                ),
                if (_accountNumberController.text.isNotEmpty) ...[
                  ReceiptDetail(
                    label: 'Account Number',
                    value: _accountNumberController.text,
                  ),
                  ReceiptDetail(
                    label: 'Account Name',
                    value: _accountNameController.text,
                  ),
                  ReceiptDetail(
                    label: 'Bank Name',
                    value: _bankNameController.text,
                  ),
                ],
                ReceiptDetail(label: 'Status', value: 'Pending Verification'),
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
          responseData['message']?.toString().contains('PIN') == true) {
        throw Exception(responseData['message'] ?? 'Invalid PIN');
      } else {
        Navigator.pop(context);
        _showSnackBar(
          responseData['message'] ?? 'Failed to swap airtime',
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

  String _formatBalance(double balance) {
    return balance
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  // Purple accent color for airtime swap
  static const Color _accentColor = Color(0xFF9C27B0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          Column(
            children: [
              // Modern Gradient Header
              ModernFormWidgets.buildGradientHeader(
                context: context,
                title: 'Airtime Swap',
                walletBalance: _walletNaira,
                isLoadingBalance: _isLoadingWallet,
                primaryColor: _accentColor,
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Card
                      ModernFormWidgets.buildInfoCard(
                        message: 'Convert your airtime to cash. Send airtime from your phone and receive money in your wallet at $_conversionRate% rate.',
                        icon: Icons.swap_horiz_rounded,
                        color: _accentColor,
                      ),
                      const SizedBox(height: 20),

                      // Network Selection Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Select Network',
                              icon: Icons.cell_tower_rounded,
                              iconColor: _accentColor,
                            ),
                            const SizedBox(height: 14),
                            ModernFormWidgets.buildNetworkGrid(
                              networks: _networks,
                              selectedId: _selectedNetwork,
                              onSelect: (id, name) {
                                setState(() {
                                  _selectedNetwork = id;
                                  _selectedNetworkName = name;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone Number Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ModernFormWidgets.buildSectionLabel(
                                  'Phone Number',
                                  icon: Icons.phone_android_rounded,
                                  iconColor: _accentColor,
                                ),
                                TextButton.icon(
                                  onPressed: _selectContact,
                                  icon: Icon(Icons.contacts_rounded, size: 16, color: _accentColor),
                                  label: Text(
                                    'Contacts',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _accentColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    backgroundColor: _accentColor.withOpacity(0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildTextField(
                              controller: _phoneController,
                              hintText: 'Enter 11-digit phone number',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(11),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amount Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Airtime Amount',
                              icon: Icons.payments_outlined,
                              iconColor: _accentColor,
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildTextField(
                              controller: _amountController,
                              hintText: 'Enter airtime amount (₦100 - ₦50,000)',
                              prefixIcon: Icons.money_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Min: ₦100 | Max: ₦50,000',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Rate/Conversion Display
                      ModernFormWidgets.buildFormCard(
                        backgroundColor: _accentColor.withOpacity(0.08),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Conversion Rate',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _accentColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$_conversionRate%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _accentColor.withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'You Will Receive',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '₦${_formatBalance(_cashAmount)}',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: _accentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Will be credited to your wallet',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bank Details (Optional)
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ModernFormWidgets.buildSectionLabel(
                                  'Bank Details',
                                  icon: Icons.account_balance_outlined,
                                  iconColor: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Optional',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Provide your bank details for direct transfer instead of wallet credit',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ModernFormWidgets.buildTextField(
                              controller: _accountNumberController,
                              hintText: 'Account number (10 digits)',
                              prefixIcon: Icons.credit_card_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildTextField(
                              controller: _accountNameController,
                              hintText: 'Account name',
                              prefixIcon: Icons.person_outline,
                              keyboardType: TextInputType.name,
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildTextField(
                              controller: _bankNameController,
                              hintText: 'Bank name',
                              prefixIcon: Icons.business_outlined,
                              keyboardType: TextInputType.text,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tips Info Card
                      ModernFormWidgets.buildInfoCard(
                        message: 'After submitting, transfer the airtime amount to our designated number. Your swap will be processed after verification.',
                        icon: Icons.lightbulb_outline_rounded,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 24),

                      // Primary Action Button
                      ModernFormWidgets.buildPrimaryButton(
                        label: 'Swap Airtime',
                        onPressed: _proceedToPin,
                        isLoading: _isLoading,
                        backgroundColor: _accentColor,
                        icon: Icons.swap_horiz_rounded,
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                      const Text(
                        'Processing...',
                        style: TextStyle(
                          fontSize: 14,
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
    );
  }
}
