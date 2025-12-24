import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
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

  Map<String, dynamic>? _selectedBank;
  bool _isLoading = false;
  bool _isVerifyingAccount = false;
  bool _showBankList = false;

  // Nigerian Banks with their codes
  final List<Map<String, dynamic>> _nigerianBanks = [
    {
      'name': 'Access Bank',
      'code': '044',
      'logo': 'assets/images/banks/access.png',
      'color': Color(0xFFFF6B00),
    },
    {
      'name': 'GTBank',
      'code': '058',
      'logo': 'assets/images/banks/gtbank.png',
      'color': Color(0xFFFF6600),
    },
    {
      'name': 'Zenith Bank',
      'code': '057',
      'logo': 'assets/images/banks/zenith.png',
      'color': Color(0xFFE2001A),
    },
    {
      'name': 'First Bank',
      'code': '011',
      'logo': 'assets/images/banks/firstbank.png',
      'color': Color(0xFF003366),
    },
    {
      'name': 'UBA',
      'code': '033',
      'logo': 'assets/images/banks/uba.png',
      'color': Color(0xFFE31E24),
    },
    {
      'name': 'Ecobank',
      'code': '050',
      'logo': 'assets/images/banks/ecobank.png',
      'color': Color(0xFF003DA5),
    },
    {
      'name': 'Fidelity Bank',
      'code': '070',
      'logo': 'assets/images/banks/fidelity.png',
      'color': Color(0xFF6B3FA0),
    },
    {
      'name': 'Union Bank',
      'code': '032',
      'logo': 'assets/images/banks/union.png',
      'color': Color(0xFF003366),
    },
    {
      'name': 'FCMB',
      'code': '214',
      'logo': 'assets/images/banks/fcmb.png',
      'color': Color(0xFFD4AF37),
    },
    {
      'name': 'Sterling Bank',
      'code': '232',
      'logo': 'assets/images/banks/sterling.png',
      'color': Color(0xFFE31E24),
    },
    {
      'name': 'Stanbic IBTC',
      'code': '221',
      'logo': 'assets/images/banks/stanbic.png',
      'color': Color(0xFF003DA5),
    },
    {
      'name': 'Polaris Bank',
      'code': '076',
      'logo': 'assets/images/banks/polaris.png',
      'color': Color(0xFF00539F),
    },
    {
      'name': 'Wema Bank',
      'code': '035',
      'logo': 'assets/images/banks/wema.png',
      'color': Color(0xFF5F259F),
    },
    {
      'name': 'Keystone Bank',
      'code': '082',
      'logo': 'assets/images/banks/keystone.png',
      'color': Color(0xFF008080),
    },
    {
      'name': 'Heritage Bank',
      'code': '030',
      'logo': 'assets/images/banks/heritage.png',
      'color': Color(0xFFFF6B00),
    },
    {
      'name': 'Unity Bank',
      'code': '215',
      'logo': 'assets/images/banks/unity.png',
      'color': Color(0xFF0066CC),
    },
    {
      'name': 'Providus Bank',
      'code': '101',
      'logo': 'assets/images/banks/providus.png',
      'color': Color(0xFF000080),
    },
    {
      'name': 'Jaiz Bank',
      'code': '301',
      'logo': 'assets/images/banks/jaiz.png',
      'color': Color(0xFF008000),
    },
    {
      'name': 'Kuda Bank',
      'code': '090267',
      'logo': 'assets/images/banks/kuda.png',
      'color': Color(0xFF40196D),
    },
    {
      'name': 'Opay',
      'code': '999992',
      'logo': 'assets/images/banks/opay.png',
      'color': Color(0xFF00C853),
    },
    {
      'name': 'PalmPay',
      'code': '999991',
      'logo': 'assets/images/banks/palmpay.png',
      'color': Color(0xFF6C3FC1),
    },
    {
      'name': 'Moniepoint',
      'code': '50515',
      'logo': 'assets/images/banks/moniepoint.png',
      'color': Color(0xFF1E88E5),
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
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

      print('📡 Verify Account Status: ${response.statusCode}');
      print('📦 Verify Account Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body)['result'][0];
        final accountName =
            result['account_name'] ?? result['data']?['account_name'];

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
        _showSnackBar(result['message'] ?? 'Verification failed', Colors.red);
      }
    } catch (e) {
      print('Error verifying account: $e');
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

      print('📡 Create Payout Account Status: ${response.statusCode}');
      print('📦 Create Payout Account Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        _showSnackBar(
          result['message'] ?? 'Payout account created successfully',
          Colors.green,
        );
        Navigator.pop(context, true);
      } else {
        final result = jsonDecode(response.body);
        _showSnackBar(
          result['message'] ?? 'Failed to create payout account',
          Colors.red,
        );
      }
    } catch (e) {
      print('Error creating payout account: $e');
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
      ),
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
                          const Expanded(
                            child: Text(
                              'Add Bank Account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
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
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Select Bank Section
                        _buildLabel('Select Bank'),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            setState(() => _showBankList = !_showBankList);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.lightGrey,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_selectedBank != null) ...[
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _selectedBank!['color']
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.account_balance,
                                        color: _selectedBank!['color'],
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedBank!['name'],
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          'Code: ${_selectedBank!['code']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else
                                  Expanded(
                                    child: Text(
                                      'Tap to select a bank',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                Icon(
                                  _showBankList
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Bank List (Expandable)
                        if (_showBankList) ...[
                          const SizedBox(height: 16),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 400),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.lightGrey.withOpacity(0.5),
                              ),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _nigerianBanks.length,
                              itemBuilder: (context, index) {
                                final bank = _nigerianBanks[index];
                                final isSelected =
                                    _selectedBank?['code'] == bank['code'];

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedBank = bank;
                                      _showBankList = false;
                                      _accountNameController.clear();
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withOpacity(0.05)
                                          : Colors.transparent,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppColors.lightGrey
                                              .withOpacity(0.3),
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                      leading: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: bank['color'].withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.account_balance,
                                            color: bank['color'],
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        bank['name'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Code: ${bank['code']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      trailing: isSelected
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: AppColors.primary,
                                            )
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Account Number
                        _buildLabel('Account Number'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _accountNumberController,
                                keyboardType: TextInputType.number,
                                maxLength: 10,
                                decoration: InputDecoration(
                                  hintText: 'Enter 10-digit account number',
                                  counterText: '',
                                  filled: true,
                                  fillColor: AppColors.cardBackground,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                    borderSide: BorderSide(
                                      color: AppColors.lightGrey,
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                    borderSide: BorderSide(
                                      color: AppColors.lightGrey,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Account number is required';
                                  }
                                  if (value.length != 10) {
                                    return 'Account number must be 10 digits';
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
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isVerifyingAccount
                                    ? null
                                    : _verifyAccountNumber,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
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
                                    : const Icon(
                                        Icons.search,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Account Name
                        _buildLabel('Account Name'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _accountNameController,
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: 'Account name will appear here',
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                              borderSide: BorderSide(
                                color: AppColors.lightGrey,
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5),
                              borderSide: BorderSide(
                                color: AppColors.lightGrey,
                                width: 1,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please verify account number first'
                              : null,
                        ),

                        const SizedBox(height: 40),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _createPayoutAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.textColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              disabledBackgroundColor: AppColors.lightGrey,
                            ),
                            child: const Text(
                              'Add Account',
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
}
