import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../services/auth_service.dart';
import '../reusable/pin_entry_screen.dart';
import '../reusable/receipt_screen.dart';

class EducationPinScreen extends StatefulWidget {
  const EducationPinScreen({super.key});

  @override
  State<EducationPinScreen> createState() => _EducationPinScreenState();
}

class _EducationPinScreenState extends State<EducationPinScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  String? _selectedProvider;
  String? _selectedType;
  double _walletNaira = 0.0;
  bool _isLoadingWallet = true;
  bool _isLoading = false;
  double _calculatedAmount = 0.0;

  // Default providers with their prices
  final List<Map<String, dynamic>> _providers = [
    {
      'serviceId': 'waec',
      'name': 'WAEC',
      'types': [
        {
          'variationCode': 'waecdirect',
          'name': 'WAEC Direct',
          'price': 3900.00,
        },
      ],
    },
    // {
    //   'serviceId': 'neco',
    //   'name': 'NECO',
    //   'types': [
    //     {
    //       'variationCode': 'necodirect',
    //       'name': 'NECO Direct',
    //       'price': 1000.00,
    //     },
    //   ],
    // },
    // {
    //   'serviceId': 'nabteb',
    //   'name': 'NABTEB',
    //   'types': [
    //     {
    //       'variationCode': 'nabtebdirect',
    //       'name': 'NABTEB Direct',
    //       'price': 1500.00,
    //     },
    //   ],
    // },
  ];

  List<Map<String, dynamic>> _availableTypes = [];
  double _selectedPrice = 0.0;

  @override
  void dispose() {
    _phoneController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
    _quantityController.addListener(_calculateAmount);
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

  void _onProviderSelected(String? providerName) {
    if (providerName == null) return;

    final provider = _providers.firstWhere(
      (p) => p['name'] == providerName,
      orElse: () => {},
    );

    setState(() {
      _selectedProvider = providerName;
      _availableTypes = List<Map<String, dynamic>>.from(
        provider['types'] ?? [],
      );
      _selectedType = null;
      _selectedPrice = 0.0;
      _calculateAmount();
    });
  }

  void _onTypeSelected(String? typeName) {
    if (typeName == null) return;

    final type = _availableTypes.firstWhere(
      (t) => t['name'] == typeName,
      orElse: () => {},
    );

    setState(() {
      _selectedType = typeName;
      _selectedPrice = type['price'] ?? 0.0;
      _calculateAmount();
    });
  }

  void _calculateAmount() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    setState(() {
      _calculatedAmount = quantity * _selectedPrice;
    });
  }

  Future<void> _proceedToPin() async {
    // Validation
    if (_selectedProvider == null) {
      _showSnackBar('Please select a provider', Colors.red);
      return;
    }

    if (_selectedType == null) {
      _showSnackBar('Please select a type', Colors.red);
      return;
    }

    if (_phoneController.text.isEmpty) {
      _showSnackBar('Please enter phone number', Colors.red);
      return;
    }

    if (_phoneController.text.length != 11) {
      _showSnackBar('Phone number must be 11 digits', Colors.red);
      return;
    }

    if (_quantityController.text.isEmpty) {
      _showSnackBar('Please enter quantity', Colors.red);
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      _showSnackBar('Quantity must be at least 1', Colors.red);
      return;
    }

    if (_calculatedAmount > _walletNaira) {
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

    // Navigate to PIN screen
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinEntryScreen(
          title: 'Confirm Purchase',
          subtitle: 'Enter your 4 digit PIN to purchase education PIN',
          onPinComplete: (pin) => _purchaseEducationPin(pin),
          onForgotPin: () {
            Navigator.pop(context);
            _showSnackBar('Contact support to reset PIN', Colors.orange);
          },
        ),
      ),
    );
  }

  Future<void> _purchaseEducationPin(String pin) async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final quantity = int.tryParse(_quantityController.text) ?? 1;

      // Get serviceId and variationCode
      final provider = _providers.firstWhere(
        (p) => p['name'] == _selectedProvider,
      );
      final type = _availableTypes.firstWhere(
        (t) => t['name'] == _selectedType,
      );

      final payload = {
        'serviceId': provider['serviceId'],
        'variationCode': type['variationCode'],
        'amount': _calculatedAmount.toStringAsFixed(2),
        'phone': _phoneController.text,
        'quantity': quantity,
        'pin': pin,
      };

      print('Education PIN payload: $payload');

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/vtu/edupin'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);
      print('Education PIN response: $responseData');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context); // Close PIN screen

        // Refresh wallet balance
        _fetchWalletBalance();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              title: 'Purchase Successful',
              subtitle: 'Your education PIN purchase was successful',
              details: [
                ReceiptDetail(
                  label: 'Transaction ID',
                  value:
                      responseData['reference']?.toString() ??
                      responseData['data']?['reference']?.toString() ??
                      'N/A',
                ),
                ReceiptDetail(
                  label: 'Provider',
                  value: _selectedProvider ?? '',
                ),
                ReceiptDetail(label: 'Type', value: _selectedType ?? ''),
                ReceiptDetail(
                  label: 'Phone Number',
                  value: _phoneController.text,
                ),
                ReceiptDetail(label: 'Quantity', value: quantity.toString()),
                ReceiptDetail(
                  label: 'Price per PIN',
                  value: '₦${_selectedPrice.toStringAsFixed(2)}',
                ),
                ReceiptDetail(
                  label: 'Total Amount',
                  value: '₦${_calculatedAmount.toStringAsFixed(2)}',
                ),
                if (responseData['pins'] != null)
                  ReceiptDetail(
                    label: 'PIN(s)',
                    value: responseData['pins'].toString(),
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
          responseData['message']?.toString().contains('PIN') == true) {
        throw Exception(responseData['message'] ?? 'Invalid PIN');
      } else {
        Navigator.pop(context);
        _showSnackBar(
          responseData['message'] ?? 'Failed to purchase education PIN',
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
                                  'Education PIN',
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
                      // Select Provider
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
                            _buildDropdown(
                              hint: 'Select a provider',
                              value: _selectedProvider,
                              items: _providers
                                  .map((p) => p['name'] as String)
                                  .toList(),
                              onChanged: _onProviderSelected,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Select Type
                      _buildLabel('Type'),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        hint: 'Select type',
                        value: _selectedType,
                        items: _availableTypes
                            .map((t) => t['name'] as String)
                            .toList(),
                        onChanged: _onTypeSelected,
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

                      // Quantity
                      _buildLabel('Quantity'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _quantityController,
                        hintText: 'Enter quantity',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),

                      // Amount Display
                      _buildLabel('Total Amount'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '₦${_formatBalance(_calculatedAmount)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),

                      if (_selectedPrice > 0) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Price per PIN: ₦${_selectedPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textColor.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],

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
        border: Border.all(color: AppColors.lightGrey, width: 1),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.lightGrey, width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: keyboardType == TextInputType.phone ? 11 : null,
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
