import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../services/auth_service.dart';
import '../reusable/pin_entry_screen.dart';
import '../reusable/receipt_screen.dart';

class EducationPinScreen extends StatefulWidget {
  const EducationPinScreen({super.key});

  @override
  State<EducationPinScreen> createState() => _EducationPinScreenState();
}

class _EducationPinScreenState extends State<EducationPinScreen> {
  // Use unified app primary color
  static const Color _accentColor = AppColors.primary;

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
  int _selectedQuantity = 1;

  // Quantity options
  final List<int> _quantityOptions = [1, 2, 3, 4, 5, 10];

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
    {
      'serviceId': 'neco',
      'name': 'NECO',
      'types': [
        {
          'variationCode': 'necodirect',
          'name': 'NECO Direct',
          'price': 1000.00,
        },
      ],
    },
    {
      'serviceId': 'nabteb',
      'name': 'NABTEB',
      'types': [
        {
          'variationCode': 'nabtebdirect',
          'name': 'NABTEB Direct',
          'price': 1500.00,
        },
      ],
    },
    {
      'serviceId': 'jamb',
      'name': 'JAMB',
      'types': [
        {
          'variationCode': 'jambdirect',
          'name': 'JAMB Direct',
          'price': 5000.00,
        },
      ],
    },
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
    _quantityController.text = _selectedQuantity.toString();
  }

  void _onQuantitySelected(int quantity) {
    setState(() {
      _selectedQuantity = quantity;
      _quantityController.text = quantity.toString();
      _calculateAmount();
    });
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
                title: 'Education PIN',
                subtitle: 'Purchase exam PINs instantly',
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
                      // Exam Type Selector Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Select Exam Type',
                              icon: Icons.school_outlined,
                              iconColor: _accentColor,
                            ),
                            const SizedBox(height: 16),
                            _buildExamTypeSelector(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Plan Selection (if provider selected)
                      if (_selectedProvider != null && _availableTypes.isNotEmpty) ...[
                        ModernFormWidgets.buildFormCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ModernFormWidgets.buildSectionLabel(
                                'Select Plan',
                                icon: Icons.list_alt_outlined,
                                iconColor: _accentColor,
                              ),
                              const SizedBox(height: 12),
                              ModernFormWidgets.buildDropdown<String>(
                                label: '',
                                hint: 'Select plan type',
                                value: _selectedType,
                                items: _availableTypes.map((t) => t['name'] as String).toList(),
                                getLabel: (item) => item,
                                onChanged: _onTypeSelected,
                                prefixIcon: Icons.assignment_outlined,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Quantity Selector
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Quantity',
                              icon: Icons.numbers_outlined,
                              iconColor: _accentColor,
                            ),
                            const SizedBox(height: 12),
                            _buildQuantitySelector(),
                            const SizedBox(height: 12),
                            // Custom quantity input
                            ModernFormWidgets.buildTextField(
                              controller: _quantityController,
                              hintText: 'Or enter custom quantity',
                              prefixIcon: Icons.edit_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (value) {
                                final qty = int.tryParse(value) ?? 1;
                                setState(() {
                                  _selectedQuantity = qty;
                                  _calculateAmount();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amount Display Card
                      ModernFormWidgets.buildFormCard(
                        backgroundColor: _accentColor.withOpacity(0.05),
                        child: Column(
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Total Amount',
                              icon: Icons.payments_outlined,
                              iconColor: _accentColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '₦${_formatBalance(_calculatedAmount)}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _accentColor,
                              ),
                            ),
                            if (_selectedPrice > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                '₦${_selectedPrice.toStringAsFixed(0)} × $_selectedQuantity PIN(s)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone/Email for delivery
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Delivery Contact',
                              icon: Icons.phone_android_outlined,
                              iconColor: _accentColor,
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildTextField(
                              controller: _phoneController,
                              hintText: 'Enter phone number (11 digits)',
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

                      // Info Card
                      ModernFormWidgets.buildInfoCard(
                        message: 'Education PINs will be sent to the phone number provided. '
                            'Please ensure the number is correct before proceeding.',
                        icon: Icons.lightbulb_outline,
                        color: _accentColor,
                      ),
                      const SizedBox(height: 24),

                      // Buy PIN Button
                      ModernFormWidgets.buildPrimaryButton(
                        label: 'Buy PIN',
                        onPressed: _proceedToPin,
                        isLoading: _isLoading,
                        backgroundColor: _accentColor,
                        icon: Icons.shopping_cart_checkout,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(
                  color: _accentColor,
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExamTypeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _providers.map((provider) {
        final name = provider['name'] as String;
        final isSelected = _selectedProvider == name;
        
        IconData getExamIcon(String examName) {
          switch (examName.toUpperCase()) {
            case 'WAEC':
              return Icons.school;
            case 'NECO':
              return Icons.menu_book;
            case 'NABTEB':
              return Icons.engineering;
            case 'JAMB':
              return Icons.account_balance;
            default:
              return Icons.school_outlined;
          }
        }
        
        return GestureDetector(
          onTap: () => _onProviderSelected(name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? _accentColor.withOpacity(0.12) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _accentColor : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  getExamIcon(name),
                  size: 24,
                  color: isSelected ? _accentColor : Colors.grey.shade600,
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? _accentColor : AppColors.textColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuantitySelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _quantityOptions.map((qty) {
        final isSelected = _selectedQuantity == qty;
        return GestureDetector(
          onTap: () => _onQuantitySelected(qty),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? _accentColor : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _accentColor : Colors.grey.shade200,
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              qty.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
