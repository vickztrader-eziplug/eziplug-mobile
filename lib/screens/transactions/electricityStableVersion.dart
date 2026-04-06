import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
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
            'logo': 'aassets/images/biller/abedc.png',
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
    final meterNumber = _meterController.text;

    // Verify meter when it reaches typical length (10-13 digits)
    if (meterNumber.length >= 10 && meterNumber.length <= 13) {
      if (_selectedProviderServiceId != null && _selectedType != null) {
        _verifyMeterNumber();
      }
    } else {
      // Clear verification when meter number changes
      if (_customerName != null || _meterVerificationError != null) {
        setState(() {
          _customerName = null;
          _meterVerificationError = null;
        });
      }
    }
  }

  Future<void> _verifyMeterNumber() async {
    if (_isVerifyingMeter) return;

    setState(() {
      _isVerifyingMeter = true;
      _customerName = null;
      _meterVerificationError = null;
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
        setState(() {
          _customerName =
              data['results']['data']['content']['Customer_Name'] ?? 'Verified';
          _meterVerificationError = null;
        });
        print('Customer name: $_customerName');
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
      _showSnackBar('Please wait for meter verification', Colors.red);
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
                if (responseData['results']['token'] != null ||
                    responseData['results']['Token'].isNotEmpty)
                  ReceiptDetail(
                    label: 'Token',
                    value: responseData['results']['data']['token'].toString(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isDark ? AppColors.headerDark : AppColors.primary,
                    isDark ? AppColors.headerDark : AppColors.primary,
                  ],
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
                                  'Electricity Bill',
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
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Select Provider - Now with bottom sheet
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Select Provider'),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _showProviderBottomSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: AppColors.lightGrey,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Provider Logo (if selected)
                                    if (_selectedProviderLogo != null) ...[
                                      _buildProviderLogo(
                                        _selectedProviderLogo,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Text(
                                        _selectedProviderName ??
                                            'Select a provider',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _selectedProviderName != null
                                              ? (theme.textTheme.bodyMedium?.color ?? AppColors.textColor)
                                              : (theme.textTheme.bodyMedium?.color?.withOpacity(0.5) ?? AppColors.textColor.withOpacity(
                                                  0.5,
                                                )),
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      color: theme.textTheme.bodyMedium?.color ?? AppColors.textColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Select Type
                      _buildLabel('Meter Type'),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        hint: 'Select type',
                        value: _selectedType,
                        items: _types,
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value;
                            _customerName = null;
                            _meterVerificationError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Meter Number with Verification
                      _buildLabel('Meter Number'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _meterController,
                        hintText: 'Enter meter number',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),

                      // Verification Status
                      if (_isVerifyingMeter)
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Verifying meter...',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6) ?? AppColors.textColor.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),

                      if (_customerName != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Verified',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      _customerName!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: theme.textTheme.bodyMedium?.color ?? AppColors.textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_meterVerificationError != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _meterVerificationError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Phone Number
                      _buildLabel('Phone Number'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _phoneController,
                        hintText: 'Enter phone number',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 20),

                      // Amount Section with Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('Amount'),
                          Row(
                            children: [
                              Text(
                                'Custom',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? AppColors.textColor.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
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
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _showCustomAmount
                            ? _buildTextField(
                                controller: _customAmountController,
                                hintText: 'Enter amount',
                                keyboardType: TextInputType.number,
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _amounts.map((amount) {
                                  return _buildAmountChip(amount);
                                }).toList(),
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

  String _formatBalance(double balance) {
    return balance
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.lightGrey, width: 1),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(
          hint,
          style: TextStyle(
            fontSize: 14,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5) ?? AppColors.textColor.withOpacity(0.5),
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

  Widget _buildAmountChip(int amount) {
    final isSelected = _selectedAmount == amount;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAmount = amount;
          _customAmountController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.light,
            width: 1,
          ),
        ),
        child: Text(
          '₦$amount',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : (Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textColor),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textColor,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.lightGrey, width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: keyboardType == TextInputType.phone ? 11 : null,
        style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color ?? AppColors.textColor),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 14,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5) ?? AppColors.textColor.withOpacity(0.5),
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
      return const Center(
        child: Icon(Icons.electric_bolt, color: Colors.amber, size: 24),
      );
    }

    // Check if it's a network URL
    if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
      return Image.network(
        logoPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.electric_bolt, color: Colors.amber, size: 24),
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
          return const Center(
            child: Icon(Icons.electric_bolt, color: Colors.amber, size: 24),
          );
        },
      );
    }

    // Fallback for emoji or other text
    return Center(child: Text(logoPath, style: const TextStyle(fontSize: 24)));
  }

  // Update the bottom sheet to use the new helper
  void _showProviderBottomSheet() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
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
                  Text(
                    'Select Provider',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.titleLarge?.color ?? AppColors.textColor,
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
                  ? const Center(
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
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.05)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                // Provider Logo using helper
                                _buildProviderLogo(provider['logo']),
                                const SizedBox(width: 16),
                                // Provider Name
                                Expanded(
                                    Text(
                                      provider['name'],
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textColor,
                                      ),
                                    ),
                                ),
                                // Check icon for selected
                                if (isSelected)
                                  const Icon(
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
