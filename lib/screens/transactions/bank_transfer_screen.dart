import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/api_response.dart';
import '../../core/utils/toast_helper.dart';
import '../../services/auth_service.dart';

class BankTransferScreen extends StatefulWidget {
  const BankTransferScreen({super.key});

  @override
  State<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends State<BankTransferScreen> {
  bool _isLoading = true;
  bool _isCreatingAccount = false;
  Map<String, dynamic>? _virtualAccount;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadUserData();
  }

  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();

    if ((token == null || token.isEmpty) && mounted) {
      print('Not authenticated: $token');
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please login to continue';
        });
        return;
      }

      // Fetch virtual account from the dedicated endpoint
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/accounts/get-account'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('📡 Virtual Account Status: ${response.statusCode}');
      print('📦 Virtual Account Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final data = result['data'] ?? result;
        
        if (mounted) {
          setState(() {
            // Get virtual_account from response
            // Handle both wrapped (data.virtual_account) and unwrapped (data directly) formats
            if (data['virtual_account'] != null) {
              _virtualAccount = data['virtual_account'];
            } else if (data['account_number'] != null) {
              // Data is directly in 'data' without virtual_account wrapper
              _virtualAccount = data;
            }
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 404) {
        // No virtual account found - this is OK, user needs to create one
        setState(() {
          _virtualAccount = null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load account details';
        });
      }
    } catch (e) {
      print('Error loading virtual account: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  Future<void> _createVirtualAccount({int retryCount = 0}) async {
    setState(() => _isCreatingAccount = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      // Create virtual account
      final createResponse = await http.post(
        Uri.parse('${Constants.baseUrl}/accounts/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('📡 Create Account Status: ${createResponse.statusCode}');
      print('📦 Create Account Body: ${createResponse.body}');

      if (createResponse.statusCode == 200 ||
          createResponse.statusCode == 201) {
        final result = jsonDecode(createResponse.body);
        final data = result['data'] ?? result;
        
        // Check if status is pending (async account creation)
        if (data['status'] == 'pending') {
          // Auto-retry up to 3 times with delay
          if (retryCount < 3) {
            _showSnackBar(
              'Creating account... please wait',
              Colors.orange,
            );
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              await _createVirtualAccount(retryCount: retryCount + 1);
            }
            return;
          }
          
          _showSnackBar(
            result['message'] ?? 'Account creation in progress. Please try again in a few moments.',
            Colors.orange,
          );
          setState(() => _isCreatingAccount = false);
          return;
        }
        
        if (data['virtual_account'] != null) {
          // Account returned directly in create response (wrapped format)
          setState(() {
            _virtualAccount = data['virtual_account'];
            _isCreatingAccount = false;
          });
          _showSnackBar('Virtual account created successfully!', Colors.green);
        } else if (data['account_number'] != null) {
          // Account returned directly in data (unwrapped format)
          setState(() {
            _virtualAccount = data;
            _isCreatingAccount = false;
          });
          _showSnackBar('Virtual account created successfully!', Colors.green);
        } else {
          // Fallback: fetch account separately
          await _getVirtualAccount();
        }
      } else {
        final result = jsonDecode(createResponse.body);
        _showSnackBar(
          result['message'] ?? 'Failed to create virtual account',
          Colors.red,
        );
        setState(() => _isCreatingAccount = false);
      }
    } catch (e) {
      print('Error creating virtual account: $e');
      _showSnackBar('Error creating account: $e', Colors.red);
      setState(() => _isCreatingAccount = false);
    }
  }

  Future<void> _getVirtualAccount() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/accounts/get-account'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('📡 Get Account Status: ${response.statusCode}');
      print('📦 Get Account Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final data = result['data'] ?? result;

        if (mounted) {
          setState(() {
            // Handle both wrapped and unwrapped formats
            if (data['virtual_account'] != null) {
              _virtualAccount = data['virtual_account'];
            } else if (data['account_number'] != null) {
              _virtualAccount = data;
            }
            _isCreatingAccount = false;
          });

          _showSnackBar('Virtual account created successfully!', Colors.green);
        }
      } else {
        final result = jsonDecode(response.body);
        _showSnackBar(
          result['message'] ?? 'Failed to get virtual account',
          Colors.red,
        );
        setState(() => _isCreatingAccount = false);
      }
    } catch (e) {
      print('Error getting virtual account: $e');
      _showSnackBar('Error: $e', Colors.red);
      setState(() => _isCreatingAccount = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('$label copied to clipboard', Colors.green);
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    // Use ToastHelper for consistent top-positioned toasts
    ToastHelper.showSnackBar(context, message, color);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: isDark ? theme.scaffoldBackgroundColor : AppColors.primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : AppColors.primary,
        body: SafeArea(
          child: Column(
            children: [
              // Enhanced Header Section
              Container(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        const Text(
                          'Bank Transfer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),

              // Content Section
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Stack(
                    children: [
                      _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: isDark ? AppColors.primaryLight : AppColors.primary,
                              ),
                            )
                          : _virtualAccount == null
                              ? _buildCreateAccountView()
                              : _buildAccountDetailsView(),
                      if (_isCreatingAccount)
                        Container(
                          color: Colors.black54,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                                    strokeWidth: 3,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Creating virtual account...',
                                    style: TextStyle(
                                      color: theme.textTheme.bodyLarge?.color,
                                      fontSize: 16,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateAccountView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.1),
                        (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_rounded,
                    size: 60,
                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'No Virtual Account',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create a dedicated virtual account to receive instant bank transfers',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? (theme.textTheme.bodyMedium?.color?.withOpacity(0.7)) : Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCreatingAccount ? null : _createVirtualAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Create Virtual Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Benefits section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Benefits',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 16),
                _buildBenefitItem(
                  Icons.flash_on_rounded,
                  'Instant Funding',
                  'Wallet credited automatically',
                  const Color(0xFFFF9800),
                ),
                const SizedBox(height: 12),
                _buildBenefitItem(
                  Icons.money_off_rounded,
                  'Zero Fees',
                  'No transfer charges',
                  const Color(0xFF4CAF50),
                ),
                const SizedBox(height: 12),
                _buildBenefitItem(
                  Icons.security_rounded,
                  'Secure & Private',
                  'Your dedicated account',
                  const Color(0xFF2196F3),
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.red.withOpacity(0.1) : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String subtitle, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? theme.textTheme.bodySmall?.color?.withOpacity(0.7) : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountDetailsView() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Instructions Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2196F3).withOpacity(0.1),
                  const Color(0xFF2196F3).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF1976D2),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Transfer to this account to fund your wallet instantly',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? theme.textTheme.bodyMedium?.color?.withOpacity(0.7) : Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Virtual Account Card (styled like a bank card)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.8),
                  const Color(0xFF1A237E),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -20,
                  left: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Virtual Account',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Active',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _virtualAccount!['bank_name'] ?? _virtualAccount!['bank'] ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _virtualAccount!['account_number'] ?? 'N/A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _copyToClipboard(
                            _virtualAccount!['account_number'] ?? '',
                            'Account Number',
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.copy_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _virtualAccount!['account_name'] ?? 'N/A',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Copy Buttons
          Row(
            children: [
              Expanded(
                child: _buildQuickCopyButton(
                  'Copy Account Number',
                  Icons.numbers_rounded,
                  _virtualAccount!['account_number'] ?? '',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickCopyButton(
                  'Copy Bank Name',
                  Icons.account_balance_rounded,
                  _virtualAccount!['bank_name'] ?? _virtualAccount!['bank'] ?? '',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Refresh Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _loadUserData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh Account Details'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                side: BorderSide(color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCopyButton(String label, IconData icon, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _copyToClipboard(value, label),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isDark ? AppColors.primaryLight : AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
