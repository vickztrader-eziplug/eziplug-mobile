import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
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
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            _walletNaira =
                double.tryParse(data['wallet_naira']?.toString() ?? '0') ?? 0.0;
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
        if (mounted && data['status'] == true) {
          setState(() {
            _conversionRate = data['data']['conversion_rate'] ?? 85;
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
              height: 260,
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
                    const SizedBox(height: 20),
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
                            child: Column(
                              children: [
                                const Text(
                                  'Airtime Swap',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _isLoadingWallet
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Balance: ₦${_formatBalance(_walletNaira)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white70,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Phone Number
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildLabel('Phone Number'),
                                ),
                                const SizedBox(width: 80),
                                Expanded(
                                  flex: 1,
                                  child: SizedBox(
                                    height: 25,
                                    child: TextButton(
                                      onPressed: _selectContact,
                                      style: TextButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          side: const BorderSide(
                                            color: AppColors.lightGrey,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Select Contact',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.light,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _phoneController,
                              hintText: 'Phone Number',
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Select Network
                      _buildLabel('Select Network'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _networks.map((network) {
                          return _buildNetworkCard(
                            network['id'],
                            network['name'],
                            network['color'],
                            network['assetPath'],
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 30),

                      // Airtime Amount
                      _buildLabel('Airtime Amount'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _amountController,
                        hintText: 'Enter airtime amount',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Min: ₦100 | Max: ₦50,000',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textColor.withOpacity(0.6),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Account Details Section (Optional)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Account Details (Optional)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Provide your bank details if you prefer direct transfer instead of wallet credit',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textColor.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Account Number
                            _buildLabel('Account Number'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _accountNumberController,
                              hintText: 'Enter 10-digit account number',
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),

                            // Account Name
                            _buildLabel('Account Name'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _accountNameController,
                              hintText: 'Enter account name',
                              keyboardType: TextInputType.text,
                            ),
                            const SizedBox(height: 16),

                            // Bank Name
                            _buildLabel('Bank Name'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _bankNameController,
                              hintText: 'Enter bank name',
                              keyboardType: TextInputType.text,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // You're getting
                      _buildLabel("Expected Amount ($_conversionRate% rate)"),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '₦${_cashAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Request will be verified before payment',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Proceed Button
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
                          child: const Text(
                            'Proceed',
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

  Widget _buildNetworkCard(
  String id,
  String name,
  Color color,
  String assetPath,
) {
  final isSelected = _selectedNetwork == id;

  return Expanded(
    child: GestureDetector(
      onTap: () {
          setState(() {
            _selectedNetwork = id;
            _selectedNetworkName = name;
          });
        },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.lightGrey.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  assetPath,
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.phone_android,
                      color: Colors.white,
                      size: 24,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textColor,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    // Determine max length based on hint text
    int? maxLength;
    if (keyboardType == TextInputType.phone) {
      maxLength = 11;
    } else if (hintText.contains('account number')) {
      maxLength = 10;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.lightGrey, width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: const TextStyle(fontSize: 14, color: AppColors.textColor),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 14,
            color: AppColors.textColor.withOpacity(0.5),
          ),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
