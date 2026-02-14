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
import '../../core/widgets/pin_verification_modal.dart';
import '../../services/auth_service.dart';
import '../reusable/receipt_screen.dart';

class AirtimeSwapScreen extends StatefulWidget {
  const AirtimeSwapScreen({super.key});

  @override
  State<AirtimeSwapScreen> createState() => _AirtimeSwapScreenState();
}

class _AirtimeSwapScreenState extends State<AirtimeSwapScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String? _selectedNetwork;
  String? _selectedNetworkName;
  double _walletNaira = 0.0;
  bool _isLoadingWallet = true;
  bool _isLoading = false;
  double _cashAmount = 0.0;
  int _conversionRate = 85; // Default 85%
  bool _hasConfirmedAirtimeSent = false; // Confirmation state
  
  // Transfer numbers for each network
  final Map<String, String> _transferNumbers = {
    '1': '08031234567', // MTN
    '4': '08051234567', // GLO
    '2': '08021234567', // AIRTEL
    '3': '08091234567', // 9MOBILE
  };

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
        Uri.parse('${Constants.baseUrl}/vtu/airtime-swap/rate'),
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

    // Check confirmation
    if (!_hasConfirmedAirtimeSent) {
      _showSnackBar('Please confirm you have sent the airtime', Colors.orange);
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

    // Show PIN modal
    if (!mounted) return;

    final pin = await PinVerificationModal.show(
      context: context,
      title: 'Confirm Airtime Swap',
      subtitle: 'Enter your PIN to swap ₦${airtimeAmount.toStringAsFixed(0)} airtime',
      amount: '₦${_cashAmount.toStringAsFixed(2)}',
      transactionType: 'Airtime Swap',
      recipient: _phoneController.text,
      onForgotPin: () {
        _showSnackBar('Contact support to reset PIN', Colors.orange);
      },
    );

    if (pin != null && pin.length == 4) {
      _processSwap(pin);
    }
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
        final data = responseData['data'] ?? {};
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              title: 'Swap Request Submitted',
              subtitle: 'Your airtime swap request is pending verification. Once approved, funds will be credited to your wallet.',
              details: [
                ReceiptDetail(
                  label: 'Transaction ID',
                  value: data['transaction_id']?.toString() ?? 'N/A',
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
                ReceiptDetail(
                  label: 'Credit To',
                  value: 'Wallet (Can withdraw after credit)',
                ),
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
        _showSnackBar('Session expired. Please login again', Colors.red);
        await authService.logout();
      } else if (response.statusCode == 400 &&
          responseData['message']?.toString().contains('PIN') == true) {
        throw Exception(responseData['message'] ?? 'Invalid PIN');
      } else {
        _showSnackBar(
          responseData['message'] ?? 'Failed to swap airtime',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
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

  // Use unified app primary color
  static const Color _accentColor = AppColors.primary;

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

                      // Step-by-Step Instructions Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.format_list_numbered_rounded,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'How to Transfer Airtime',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInstructionStep(
                              stepNumber: 1,
                              instruction: 'Dial your network\'s airtime transfer code',
                              subText: _getTransferCode(),
                            ),
                            _buildInstructionStep(
                              stepNumber: 2,
                              instruction: 'Enter the amount you want to transfer',
                              subText: _amountController.text.isNotEmpty 
                                  ? '₦${_amountController.text}' 
                                  : 'Enter amount above',
                            ),
                            _buildInstructionStep(
                              stepNumber: 3,
                              instruction: 'Enter our receiving number',
                              subText: _selectedNetwork != null 
                                  ? _transferNumbers[_selectedNetwork] ?? 'Select network first'
                                  : 'Select network first',
                              canCopy: _selectedNetwork != null,
                            ),
                            _buildInstructionStep(
                              stepNumber: 4,
                              instruction: 'Enter your transfer PIN and confirm',
                              subText: 'Complete the transfer on your phone',
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirmation Checkbox Card
                      ModernFormWidgets.buildFormCard(
                        backgroundColor: _hasConfirmedAirtimeSent 
                            ? Colors.green.withOpacity(0.08) 
                            : Colors.orange.withOpacity(0.08),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _hasConfirmedAirtimeSent = !_hasConfirmedAirtimeSent;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _hasConfirmedAirtimeSent 
                                        ? Colors.green 
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _hasConfirmedAirtimeSent 
                                          ? Colors.green 
                                          : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                  ),
                                  child: _hasConfirmedAirtimeSent
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'I Have Sent the Airtime',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _hasConfirmedAirtimeSent 
                                              ? Colors.green.shade700 
                                              : Colors.grey.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tap to confirm you have transferred the airtime',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Wallet Credit Info
                      ModernFormWidgets.buildInfoCard(
                        message: 'Once approved, funds will be credited directly to your Eziplug wallet. You can then withdraw to your bank account anytime.',
                        icon: Icons.account_balance_wallet_outlined,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 24),

                      // Primary Action Button - Only enabled after confirmation
                      ModernFormWidgets.buildPrimaryButton(
                        label: _hasConfirmedAirtimeSent ? 'Submit Swap Request' : 'Confirm Airtime Sent First',
                        onPressed: _hasConfirmedAirtimeSent ? _proceedToPin : null,
                        isLoading: _isLoading,
                        backgroundColor: _hasConfirmedAirtimeSent ? _accentColor : Colors.grey,
                        icon: _hasConfirmedAirtimeSent ? Icons.send_rounded : Icons.hourglass_empty_rounded,
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

  // Helper method to get transfer code based on network
  String _getTransferCode() {
    switch (_selectedNetwork) {
      case '1': // MTN
        return '*600*recipient*amount# or *777*recipient*amount#';
      case '4': // GLO
        return '*131*recipient*amount#';
      case '2': // AIRTEL
        return '*432*recipient*amount#';
      case '3': // 9MOBILE
        return '*223*PIN*amount*recipient#';
      default:
        return 'Select a network to see transfer code';
    }
  }

  // Helper widget for instruction steps
  Widget _buildInstructionStep({
    required int stepNumber,
    required String instruction,
    required String subText,
    bool isLast = false,
    bool canCopy = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _accentColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$stepNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: _accentColor.withOpacity(0.3),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          subText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    if (canCopy) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: subText));
                          _showSnackBar('Number copied!', Colors.green);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: _accentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
