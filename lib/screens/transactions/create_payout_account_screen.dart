import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isLoadingBanks = false;
  String? _bankLoadError;
  List<Map<String, dynamic>> _banks = [];
  List<Map<String, dynamic>> _filteredBanks = [];

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _fetchBanks();
  }

  Future<void> _fetchBanks() async {
    setState(() {
      _isLoadingBanks = true;
      _bankLoadError = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/payout/bank/list'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResult = jsonDecode(response.body);
        final data = jsonResult['data'];
        
        List<dynamic> bankList = [];
        if (data is Map && data['banks'] != null) {
          bankList = data['banks'] as List<dynamic>;
        } else if (data is List) {
          bankList = data;
        }

        setState(() {
          _banks = bankList.map((bank) {
            return {
              'name': bank['name'] ?? '',
              'code': bank['code'] ?? '',
              'color': _getBankColor(bank['name'] ?? ''),
            };
          }).toList();
          _filteredBanks = _banks;
          _isLoadingBanks = false;
        });
      } else {
        setState(() {
          _bankLoadError = 'Failed to load banks';
          _isLoadingBanks = false;
        });
      }
    } catch (e) {
      setState(() {
        _bankLoadError = 'Error loading banks: $e';
        _isLoadingBanks = false;
      });
    }
  }

  Color _getBankColor(String bankName) {
    // Map of known bank colors for visual distinction
    final colorMap = {
      'access': const Color(0xFFFF6B00),
      'gtbank': const Color(0xFFFF6600),
      'guaranty': const Color(0xFFFF6600),
      'zenith': const Color(0xFFE2001A),
      'first bank': const Color(0xFF003366),
      'uba': const Color(0xFFE31E24),
      'united bank': const Color(0xFFE31E24),
      'ecobank': const Color(0xFF003DA5),
      'fidelity': const Color(0xFF6B3FA0),
      'union': const Color(0xFF003366),
      'fcmb': const Color(0xFFD4AF37),
      'sterling': const Color(0xFFE31E24),
      'stanbic': const Color(0xFF003DA5),
      'polaris': const Color(0xFF00539F),
      'wema': const Color(0xFF5F259F),
      'keystone': const Color(0xFF008080),
      'heritage': const Color(0xFFFF6B00),
      'unity': const Color(0xFF0066CC),
      'providus': const Color(0xFF000080),
      'jaiz': const Color(0xFF008000),
      'kuda': const Color(0xFF40196D),
      'opay': const Color(0xFF00C853),
      'palmpay': const Color(0xFF6C3FC1),
      'moniepoint': const Color(0xFF1E88E5),
    };

    final lowerName = bankName.toLowerCase();
    for (final entry in colorMap.entries) {
      if (lowerName.contains(entry.key)) {
        return entry.value;
      }
    }
    // Default color for unknown banks
    return const Color(0xFF607D8B);
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
        _filteredBanks = _banks;
      } else {
        _filteredBanks = _banks
            .where((bank) =>
                (bank['name'] as String? ?? '').toLowerCase().contains(query.toLowerCase()))
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
        
        // Handle the response - account_name is directly in data now
        String? accountName;
        if (responseData is Map) {
          accountName = responseData['account_name'];
        } else if (responseData is List && responseData.isNotEmpty) {
          final firstItem = responseData[0];
          accountName = firstItem is Map ? firstItem['account_name'] : null;
        }

        if (accountName != null && accountName.isNotEmpty) {
          setState(() {
            _accountNameController.text = accountName!;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey[400], fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: isReadOnly 
          ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]) 
          : theme.cardColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!, 
          width: 1
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.primaryLight : AppColors.primary, 
          width: 1.5
        ),
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
    
    // Capture state in local variables for the modal
    final isLoading = _isLoadingBanks;
    final loadError = _bankLoadError;
    var filteredList = List<Map<String, dynamic>>.from(_banks);
    final allBanks = List<Map<String, dynamic>>.from(_banks);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          final theme = Theme.of(modalContext);
          final isDark = theme.brightness == Brightness.dark;

          return Container(
            height: MediaQuery.of(modalContext).size.height * 0.75,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text(
                        'Select Bank',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.titleLarge?.color,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(modalContext),
                        icon: Icon(Icons.close, color: theme.textTheme.bodyLarge?.color),
                      ),
                    ],
                  ),
                ),
                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      hintText: 'Search bank...',
                      hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey[400]),
                      prefixIcon:
                          Icon(Icons.search, color: isDark ? Colors.white30 : Colors.grey[400]),
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: isDark 
                            ? BorderSide(color: Colors.white.withOpacity(0.1)) 
                            : BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: isDark 
                            ? BorderSide(color: Colors.white.withOpacity(0.1)) 
                            : BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        if (value.isEmpty) {
                          filteredList = List<Map<String, dynamic>>.from(allBanks);
                        } else {
                          filteredList = allBanks
                              .where((bank) => (bank['name'] as String? ?? '')
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
                  child: isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                          ),
                        )
                      : loadError != null && loadError.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    loadError,
                                    style: TextStyle(color: theme.textTheme.bodySmall?.color),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(modalContext);
                                      _fetchBanks();
                                    },
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : filteredList.isEmpty
                              ? Center(
                                  child: Text(
                                    'No banks found',
                                    style: TextStyle(color: theme.textTheme.bodySmall?.color),
                                  ),
                                )
                              : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final bank = filteredList[index];
                      final isSelected =
                          _selectedBank?['code'] == bank['code'];

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.3))
                              : null,
                        ),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              _selectedBank = bank;
                              _accountNameController.clear();
                            });
                            Navigator.pop(modalContext);
                          },
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: (bank['color'] as Color? ?? const Color(0xFF607D8B)).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                (bank['name'] as String? ?? '').length >= 2 
                                    ? (bank['name'] as String).substring(0, 2).toUpperCase()
                                    : (bank['name'] as String? ?? 'BK').toUpperCase(),
                                style: TextStyle(
                                  color: bank['color'] as Color? ?? const Color(0xFF607D8B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            bank['name'] as String? ?? 'Unknown Bank',
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                  : theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle,
                                  color: isDark ? AppColors.primaryLight : AppColors.primary)
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: isDark ? theme.scaffoldBackgroundColor : Colors.white,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Add Bank Account',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
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
                        (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.1),
                        (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Secure Bank Linking',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: theme.textTheme.titleMedium?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your bank details are encrypted and secured.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? theme.textTheme.bodySmall?.color : Colors.grey[600],
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
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!
                      ),
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
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ] else
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.account_balance_outlined,
                                    color: isDark ? Colors.white24 : Colors.grey[400], size: 22),
                                const SizedBox(width: 12),
                                Text(
                                  'Tap to select a bank',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isDark ? Colors.white24 : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white24 : Colors.grey[400]),
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodyLarge?.color,
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
                          backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyLarge?.color,
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
                      backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey[300],
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
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.grey[500], size: 14),
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
