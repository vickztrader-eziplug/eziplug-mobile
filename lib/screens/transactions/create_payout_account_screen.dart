import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/api_response.dart';
import '../../services/auth_service.dart';

class CreatePayoutAccountScreen extends StatefulWidget {
  const CreatePayoutAccountScreen({super.key});

  @override
  State<CreatePayoutAccountScreen> createState() =>
      _CreatePayoutAccountScreenState();
}

class _CreatePayoutAccountScreenState extends State<CreatePayoutAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? _selectedBank;
  bool _isLoading = false;
  bool _isVerifyingAccount = false;
  bool _showBankList = false;
  List<Map<String, dynamic>> _filteredBanks = [];

  // Nigerian Banks with their codes
  final List<Map<String, dynamic>> _nigerianBanks = [
    {'name': 'Access Bank', 'code': '044', 'color': Color(0xFFFF6B00)},
    {'name': 'GTBank', 'code': '058', 'color': Color(0xFFFF6600)},
    {'name': 'Zenith Bank', 'code': '057', 'color': Color(0xFFE2001A)},
    {'name': 'First Bank', 'code': '011', 'color': Color(0xFF003366)},
    {'name': 'UBA', 'code': '033', 'color': Color(0xFFE31E24)},
    {'name': 'Ecobank', 'code': '050', 'color': Color(0xFF003DA5)},
    {'name': 'Fidelity Bank', 'code': '070', 'color': Color(0xFF6B3FA0)},
    {'name': 'Union Bank', 'code': '032', 'color': Color(0xFF003366)},
    {'name': 'FCMB', 'code': '214', 'color': Color(0xFFD4AF37)},
    {'name': 'Sterling Bank', 'code': '232', 'color': Color(0xFFE31E24)},
    {'name': 'Stanbic IBTC', 'code': '221', 'color': Color(0xFF003DA5)},
    {'name': 'Polaris Bank', 'code': '076', 'color': Color(0xFF00539F)},
    {'name': 'Wema Bank', 'code': '035', 'color': Color(0xFF5F259F)},
    {'name': 'Keystone Bank', 'code': '082', 'color': Color(0xFF008080)},
    {'name': 'Heritage Bank', 'code': '030', 'color': Color(0xFFFF6B00)},
    {'name': 'Unity Bank', 'code': '215', 'color': Color(0xFF0066CC)},
    {'name': 'Providus Bank', 'code': '101', 'color': Color(0xFF000080)},
    {'name': 'Jaiz Bank', 'code': '301', 'color': Color(0xFF008000)},
    {'name': 'Kuda Bank', 'code': '090267', 'color': Color(0xFF40196D)},
    {'name': 'Opay', 'code': '999992', 'color': Color(0xFF00C853)},
    {'name': 'PalmPay', 'code': '999991', 'color': Color(0xFF6C3FC1)},
    {'name': 'Moniepoint', 'code': '50515', 'color': Color(0xFF1E88E5)},
  ];

  @override
  void initState() {
    super.initState();
    _filteredBanks = _nigerianBanks;
    _checkAuth();
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterBanks(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBanks = _nigerianBanks;
      } else {
        _filteredBanks = _nigerianBanks
            .where((bank) =>
                bank['name'].toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();

    if ((token == null || token.isEmpty) && mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _verifyAccountNumber() async {
    if (_accountNumberController.text.length != 10) {
      _showSnackBar('Account number must be 10 digits', Colors.orange);
      return;
    }

    if (_selectedBank == null) {
      _showSnackBar('Please select a bank first', Colors.orange);
      return;
    }

    setState(() => _isVerifyingAccount = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/payout/account/validate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'account_number': _accountNumberController.text,
          'bank_code': _selectedBank!['code'],
        }),
      );

      if (response.statusCode == 200) {
        final jsonResult = jsonDecode(response.body);
        final responseData = getResponseData(jsonResult);
        final result = responseData is List ? responseData[0] : responseData;
        final accountName = result['account_name'];

        if (accountName != null) {
          setState(() {
            _accountNameController.text = accountName;
          });
          _showSnackBar('Account verified successfully', Colors.green);
        } else {
          _showSnackBar('Could not verify account', Colors.orange);
        }
      } else {
        final result = jsonDecode(response.body);
        _showSnackBar(
            getResponseMessage(result) ?? 'Verification failed', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() => _isVerifyingAccount = false);
    }
  }

  Future<void> _createPayoutAccount() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBank == null) {
      _showSnackBar('Please select a bank', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/payout/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bank_name': _selectedBank!['name'],
          'bank_code': _selectedBank!['code'],
          'account_name': _accountNameController.text.trim(),
          'account_number': _accountNumberController.text.trim(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        _showSnackBar(
          getResponseMessage(result) ?? 'Account added successfully!',
          Colors.green,
        );
        Navigator.pop(context, true);
      } else {
        final result = jsonDecode(response.body);
        _showSnackBar(
          getResponseMessage(result) ?? 'Failed to add account',
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText, {bool isReadOnly = false}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: isReadOnly ? Colors.grey[100] : Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  void _showBankSelector() {
    _searchController.clear();
    _filteredBanks = _nigerianBanks;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Text(
                        'Select Bank',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search bank...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        if (value.isEmpty) {
                          _filteredBanks = _nigerianBanks;
                        } else {
                          _filteredBanks = _nigerianBanks
                              .where((bank) => bank['name']
                                  .toLowerCase()
                                  .contains(value.toLowerCase()))
                              .toList();
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Bank list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filteredBanks.length,
                    itemBuilder: (context, index) {
                      final bank = _filteredBanks[index];
                      final isSelected =
                          _selectedBank?['code'] == bank['code'];

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.primary.withOpacity(0.3))
                              : null,
                        ),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              _selectedBank = bank;
                              _accountNameController.clear();
                            });
                            Navigator.pop(context);
                          },
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: (bank['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                bank['name'].substring(0, 2).toUpperCase(),
                                style: TextStyle(
                                  color: bank['color'],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            bank['name'],
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.black87,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: AppColors.primary)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Bank Account',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Secure Bank Linking',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your bank details are encrypted and secured.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Select Bank
              _buildLabel('Select Bank'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _showBankSelector,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      if (_selectedBank != null) ...[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: (_selectedBank!['color'] as Color)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              _selectedBank!['name']
                                  .substring(0, 2)
                                  .toUpperCase(),
                              style: TextStyle(
                                color: _selectedBank!['color'],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _selectedBank!['name'],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ] else
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_outlined,
                                  color: Colors.grey[400], size: 22),
                              const SizedBox(width: 12),
                              Text(
                                'Tap to select a bank',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Account Number
              _buildLabel('Account Number'),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: _inputDecoration(
                        'Enter 10-digit account number',
                      ).copyWith(counterText: ''),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Account number is required';
                        }
                        if (value.length != 10) {
                          return 'Must be 10 digits';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (value.length == 10) {
                          _verifyAccountNumber();
                        } else {
                          setState(() {
                            _accountNameController.clear();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          _isVerifyingAccount ? null : _verifyAccountNumber,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isVerifyingAccount
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.search, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Account Name
              _buildLabel('Account Name'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _accountNameController,
                readOnly: true,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: _inputDecoration(
                  'Account name will appear here',
                  isReadOnly: true,
                ).copyWith(
                  prefixIcon: _accountNameController.text.isNotEmpty
                      ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 20)
                      : null,
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please verify account number first'
                    : null,
              ),
              const SizedBox(height: 40),
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createPayoutAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline,
                                color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Add Bank Account',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              // Security badge
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      'Your data is protected with bank-level encryption',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }
}
