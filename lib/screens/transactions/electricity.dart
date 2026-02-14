import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../services/auth_service.dart';
import '../reusable/pin_entry_screen.dart';
import '../reusable/receipt_screen.dart';

class ElectricityScreen extends StatefulWidget {
  const ElectricityScreen({super.key});

  @override
  State<ElectricityScreen> createState() => _ElectricityScreenState();
}

class _ElectricityScreenState extends State<ElectricityScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _meterController = TextEditingController();
  final TextEditingController _customAmountController = TextEditingController();

  // Store both id and serviceID
  int? _selectedProviderId; // For bill purchase API
  String? _selectedProviderServiceId; // For validation API
  String? _selectedProviderName;
  String? _selectedProviderLogo;
  String? _selectedType;
  int? _selectedAmount;
  bool _isLoading = false;
  bool _isFetchingProviders = false;
  bool _isVerifyingMeter = false;
  bool _showCustomAmount = false;
  String? _customerName;
  String? _meterVerificationError;
  double _walletNaira = 0.0;
  bool _isLoadingWallet = true;
  bool _hasManuallyVerified = false; // Track if user clicked verify button

  List<Map<String, dynamic>> _providers = [];
  final List<String> _types = ['Prepaid', 'Postpaid'];
  final List<int> _amounts = [
    1000,
    2000,
    3000,
    5000,
    10000,
    15000,
    20000,
    50000,
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _meterController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _fetchProviders();
    _fetchWalletBalance();
    // Remove auto-verification listener
    _meterController.addListener(_onMeterNumberChanged);
  }

  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();

    if ((token == null || token.isEmpty) && mounted) {
      print('not authenticated: $token');
    }
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

  Future<void> _fetchProviders() async {
    setState(() => _isFetchingProviders = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.get(
        Uri.parse(Constants.bills),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        // Handle different possible response structures
        dynamic billsData;

        if (responseBody['results'] != null) {
          final results = responseBody['results'];
          billsData = results['data'] ?? results;
        } else if (responseBody['data'] != null) {
          billsData = responseBody['data'];
        } else {
          billsData = responseBody;
        }

        print('Bills data: $billsData');

        if (mounted && billsData is List) {
          setState(() {
            _providers = billsData
                .where(
                  (bill) =>
                      bill['category']?.toLowerCase() == 'electricity' ||
                      bill['type']?.toLowerCase() == 'electricity' ||
                      bill['identifier'] != null,
                )
                .map<Map<String, dynamic>>(
                  (provider) => {
                    'id': provider['id'],
                    'serviceID': provider['serviceID'] ?? '',
                    'name': provider['name'] ?? '',
                    'logo': provider['logo'] ?? provider['image'] ?? '',
                  },
                )
                .toList();

            print('Filtered providers: $_providers');
          });
        }
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        _setDefaultProviders();
      }
    } catch (e) {
      print('Error fetching providers: $e');
      _setDefaultProviders();
    } finally {
      if (mounted) setState(() => _isFetchingProviders = false);
    }
  }

  void _setDefaultProviders() {
    if (mounted) {
      setState(() {
        _providers = [
          {
            'id': 1,
            'serviceID': 'aba-electric',
            'name': 'ABA - Aba Power',
            'logo': 'assets/images/biller/abedc.png',
          },
          {
            'id': 2,
            'serviceID': 'abuja-electric',
            'name': 'AEDC - Abuja Electricity',
            'logo': 'assets/images/biller/aedc.png',
          },
          {
            'id': 3,
            'serviceID': 'benin-electric',
            'name': 'BEDC - Benin Electricity',
            'logo': 'assets/images/biller/bedc.png',
          },
          {
            'id': 4,
            'serviceID': 'eko-electric',
            'name': 'EKEDC - Eko Electricity',
            'logo': 'assets/images/biller/ekedc.png',
          },
          {
            'id': 5,
            'serviceID': 'enugu-electric',
            'name': 'EEDC - Enugu Electricity',
            'logo': 'assets/images/biller/eedc.png',
          },
          {
            'id': 6,
            'serviceID': 'ibadan-electric',
            'name': 'IBEDC - Ibadan Electricity',
            'logo': 'assets/images/biller/ibedc.png',
          },
          {
            'id': 7,
            'serviceID': 'ikeja-electric',
            'name': 'IKEDC - Ikeja Electricity',
            'logo': 'assets/images/biller/ikedc.png',
          },
          {
            'id': 8,
            'serviceID': 'jos-electric',
            'name': 'JED - Jos Electric',
            'logo': 'assets/images/biller/jedc.png',
          },
          {
            'id': 9,
            'serviceID': 'kano-electric',
            'name': 'KEDCO - Kano Electricity',
            'logo': 'assets/images/biller/kedco.png',
          },
          {
            'id': 10,
            'serviceID': 'kaduna-electric',
            'name': 'KAEDCO - Kaduna Electricity',
            'logo': 'assets/images/biller/kaedco.png',
          },
          {
            'id': 11,
            'serviceID': 'portharcourt-electric',
            'name': 'PHEDC - Port Harcourt',
            'logo': 'assets/images/biller/phedc.png',
          },
          {
            'id': 12,
            'serviceID': 'yola-electric',
            'name': 'YEDC - Yola Electricity',
            'logo': 'assets/images/biller/yedc.png',
          },
        ];
      });
    }
  }

  void _onMeterNumberChanged() {
    // Always trigger rebuild to update verify button state
    // and clear verification when meter number changes
    setState(() {
      if (_customerName != null || _meterVerificationError != null) {
        _customerName = null;
        _meterVerificationError = null;
        _hasManuallyVerified = false;
      }
    });
  }

  bool _canVerifyMeter() {
    return _selectedProviderServiceId != null &&
        _selectedType != null &&
        _meterController.text.length == 11 &&
        !_isVerifyingMeter;
  }

  Future<void> _verifyMeterNumber() async {
    if (!_canVerifyMeter()) {
      if (_selectedProviderServiceId == null) {
        _showSnackBar('Please select a provider first', Colors.orange);
      } else if (_selectedType == null) {
        _showSnackBar('Please select meter type first', Colors.orange);
      } else if (_meterController.text.length != 11) {
        _showSnackBar('Meter number must be 11 digits', Colors.orange);
      }
      return;
    }

    setState(() {
      _isVerifyingMeter = true;
      _customerName = null;
      _meterVerificationError = null;
      _hasManuallyVerified = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.post(
        Uri.parse(Constants.validate),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'billersCode': _meterController.text,
          'serviceID': _selectedProviderServiceId,
          'type': _selectedType?.toLowerCase() ?? '',
        }),
      );

      final data = jsonDecode(response.body);
      print(data);
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Extract customer name from the response
        // Backend returns: { "success": true, "message": "...", "data": { "code": "000", "content": { "Customer_Name": "..." } } }
        final content = data['data']?['content'];
        final customerName = content?['Customer_Name'] ?? content?['customer_name'];
        
        setState(() {
          _customerName = customerName ?? 'Verified';
          _meterVerificationError = null;
        });
        print('Customer name: $_customerName');
        _showSnackBar('Meter verified successfully', Colors.green);
      } else {
        setState(() {
          _customerName = null;
          _meterVerificationError = data['message'] ?? 'Invalid meter number';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _customerName = null;
        _meterVerificationError = 'Could not verify meter number';
      });
      print('Verification error: $e');
    } finally {
      if (mounted) setState(() => _isVerifyingMeter = false);
    }
  }

  Future<void> _proceedToPin() async {
    // Validation
    if (_selectedProviderId == null) {
      _showSnackBar('Please select a provider', Colors.red);
      return;
    }

    if (_selectedType == null) {
      _showSnackBar('Please select meter type', Colors.red);
      return;
    }

    if (_meterController.text.isEmpty) {
      _showSnackBar('Please enter meter number', Colors.red);
      return;
    }

    if (_customerName == null) {
      _showSnackBar('Please verify meter number first', Colors.red);
      return;
    }

    if (_phoneController.text.isEmpty) {
      _showSnackBar('Please enter phone number', Colors.red);
      return;
    }

    // Get amount
    int? amount = _selectedAmount;
    if (amount == null && _customAmountController.text.isNotEmpty) {
      amount = int.tryParse(_customAmountController.text.replaceAll(',', ''));
    }

    if (amount == null || amount <= 0) {
      _showSnackBar('Please select or enter an amount', Colors.red);
      return;
    }

    // Check wallet balance
    if (amount > _walletNaira) {
      _showSnackBar('Insufficient balance', Colors.red);
      return;
    }

    // Check auth right before proceeding to PIN
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
          title: 'Confirm Purchase',
          subtitle: 'Enter your 4 digit PIN to purchase electricity',
          onPinComplete: (pin) => _purchaseElectricity(pin),
          onForgotPin: () {
            Navigator.pop(context);
            _showSnackBar('Contact support to reset PIN', Colors.orange);
          },
        ),
      ),
    );
  }

  Future<void> _purchaseElectricity(String pin) async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      // Get final amount
      int amount =
          _selectedAmount ??
          int.parse(_customAmountController.text.replaceAll(',', ''));

      final payload = {
        'serviceId': _selectedProviderId.toString(),
        'billersCode': _meterController.text,
        'variationCode': _selectedType?.toLowerCase() ?? 'prepaid',
        'phone': _phoneController.text,
        'amount': amount,
        'pin': pin,
      };

      print('Purchase payload: $payload');

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/vtu/bill'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);
      print('Purchase response: $responseData');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context); // Close PIN screen

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              title: 'Purchase Successful',
              subtitle: 'Your electricity bill payment was successful',
              details: [
                ReceiptDetail(
                  label: 'Transaction ID',
                  value: responseData['reference']?.toString() ?? 'N/A',
                ),
                ReceiptDetail(
                  label: 'Provider',
                  value: _selectedProviderName ?? '',
                ),
                ReceiptDetail(
                  label: 'Customer Name',
                  value: _customerName ?? '',
                ),
                ReceiptDetail(
                  label: 'Meter Number',
                  value: _meterController.text,
                ),
                ReceiptDetail(label: 'Meter Type', value: _selectedType ?? ''),
                ReceiptDetail(
                  label: 'Phone Number',
                  value: _phoneController.text,
                ),
                ReceiptDetail(label: 'Amount', value: '₦${amount.toString()}'),
                if (responseData['results']?['token'] != null)
                  ReceiptDetail(
                    label: 'Token',
                    value: responseData['results']['token'].toString(),
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
        Navigator.pop(context);
        _showSnackBar('Session expired. Please login again', Colors.red);
        await authService.logout();
      } else if (response.statusCode == 400 &&
          responseData['message']?.toString().contains('PIN') == true) {
        throw Exception(responseData['message'] ?? 'Invalid PIN');
      } else {
        Navigator.pop(context);
        _showSnackBar(
          responseData['message'] ?? 'Failed to purchase electricity',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Use sanitized error message for production
      _showSnackBar(ErrorHandler.getUserFriendlyMessage(e), Colors.red);
      rethrow;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    // Use ToastHelper for consistent top-positioned toasts
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
              // Gradient Header
              ModernFormWidgets.buildGradientHeader(
                context: context,
                title: 'Electricity Bill',
                walletBalance: _walletNaira,
                isLoadingBalance: _isLoadingWallet,
                primaryColor: AppColors.primary,
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Provider Selection Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Select Provider',
                              icon: Icons.electrical_services,
                              iconColor: AppColors.primary,
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _showProviderBottomSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.06),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    if (_selectedProviderLogo != null) ...[
                                      _buildProviderLogo(
                                        _selectedProviderLogo,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 12),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.electric_bolt,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Text(
                                        _selectedProviderName ?? 'Select a provider',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: _selectedProviderName != null
                                              ? AppColors.textColor
                                              : Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Meter Type Selection Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Meter Type',
                              icon: Icons.speed,
                              iconColor: AppColors.primary,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: _types.map((type) {
                                final isSelected = _selectedType == type;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedType = type;
                                        _customerName = null;
                                        _meterVerificationError = null;
                                        _hasManuallyVerified = false;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: EdgeInsets.only(
                                        right: type == 'Prepaid' ? 8 : 0,
                                        left: type == 'Postpaid' ? 8 : 0,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary.withOpacity(0.12)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.grey.shade200,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.primary
                                                      .withOpacity(0.15),
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
                                            type == 'Prepaid'
                                                ? Icons.credit_card
                                                : Icons.receipt_long,
                                            size: 18,
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            type,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Meter Number Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Meter Number',
                              icon: Icons.numbers,
                              iconColor: AppColors.primary,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ModernFormWidgets.buildTextField(
                                    controller: _meterController,
                                    hintText: 'Enter 11-digit meter number',
                                    prefixIcon: Icons.electric_meter,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(11),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _canVerifyMeter()
                                        ? _verifyMeterNumber
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                      disabledBackgroundColor: Colors.grey.shade300,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                    ),
                                    child: _isVerifyingMeter
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Verify',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Verification Status
                            if (_customerName != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Verified Successfully',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _customerName!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            if (_meterVerificationError != null && _hasManuallyVerified)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _meterVerificationError!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone Number Card
                      ModernFormWidgets.buildFormCard(
                        child: ModernFormWidgets.buildTextField(
                          controller: _phoneController,
                          hintText: 'Enter phone number',
                          label: 'Phone Number',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amount Selection Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ModernFormWidgets.buildSectionLabel(
                                  'Select Amount',
                                  icon: Icons.payments_outlined,
                                  iconColor: AppColors.primary,
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Custom',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Transform.scale(
                                      scale: 0.8,
                                      child: Switch(
                                        value: _showCustomAmount,
                                        onChanged: (value) {
                                          setState(() {
                                            _showCustomAmount = value;
                                            if (value) {
                                              _selectedAmount = null;
                                            } else {
                                              _customAmountController.clear();
                                            }
                                          });
                                        },
                                        activeColor: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_showCustomAmount)
                              ModernFormWidgets.buildTextField(
                                controller: _customAmountController,
                                hintText: 'Enter amount',
                                prefixIcon: Icons.money,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              )
                            else
                              _buildAmountGrid(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info Card
                      ModernFormWidgets.buildInfoCard(
                        message:
                            'Ensure your meter number is correct. Token will be sent to your phone number after successful purchase.',
                        icon: Icons.lightbulb_outline,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ModernFormWidgets.buildPrimaryButton(
                        label: 'Proceed to Payment',
                        onPressed: _isLoading ? null : _proceedToPin,
                        isLoading: _isLoading,
                        backgroundColor: AppColors.primary,
                        icon: Icons.flash_on,
                      ),
                      const SizedBox(height: 20),
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
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAmountGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _amounts.map((amount) {
        final isSelected = _selectedAmount == amount;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedAmount = amount;
              _customAmountController.clear();
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade200,
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '₦${_formatAmount(amount)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatAmount(int amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K';
    }
    return amount.toString();
  }

  Widget _buildProviderLogo(String? logoPath, {double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildLogoImage(logoPath),
      ),
    );
  }

  Widget _buildLogoImage(String? logoPath) {
    if (logoPath == null || logoPath.isEmpty) {
      return Center(
        child: Icon(Icons.electric_bolt, color: AppColors.primary, size: 24),
      );
    }

    // Check if it's a network URL
    if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
      return Image.network(
        logoPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(Icons.electric_bolt, color: AppColors.primary, size: 24),
        ),
      );
    }

    // Check if it's a local asset
    if (logoPath.startsWith('assets/')) {
      return Image.asset(
        logoPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading asset: $logoPath');
          return Center(
            child: Icon(Icons.electric_bolt, color: AppColors.primary, size: 24),
          );
        },
      );
    }

    // Fallback for emoji or other text
    return Center(child: Text(logoPath, style: const TextStyle(fontSize: 24)));
  }

  void _showProviderBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Provider',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Providers List
            Expanded(
              child: _isFetchingProviders
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _providers.isEmpty
                      ? const Center(
                          child: Text(
                            'No providers available',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _providers.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, indent: 80),
                          itemBuilder: (context, index) {
                            final provider = _providers[index];
                            final isSelected =
                                _selectedProviderName == provider['name'];

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedProviderId = provider['id'];
                                  _selectedProviderServiceId =
                                      provider['serviceID'];
                                  _selectedProviderName = provider['name'];
                                  _selectedProviderLogo = provider['logo'];
                                  _customerName = null;
                                  _meterVerificationError = null;
                                  _hasManuallyVerified = false;
                                });
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.08)
                                    : Colors.transparent,
                                child: Row(
                                  children: [
                                    // Provider Logo using helper
                                    _buildProviderLogo(provider['logo']),
                                    const SizedBox(width: 16),
                                    // Provider Name
                                    Expanded(
                                      child: Text(
                                        provider['name'],
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: AppColors.textColor,
                                        ),
                                      ),
                                    ),
                                    // Check icon for selected
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: AppColors.primary,
                                        size: 24,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
