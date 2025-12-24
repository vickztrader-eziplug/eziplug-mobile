import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
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

      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('📡 User Data Status: ${response.statusCode}');
      print('📦 User Data Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            // Check if virtual_accounts exists and is not empty
            if (data['virtual_accounts'] != null &&
                data['virtual_accounts'].toString().isNotEmpty &&
                data['virtual_accounts'] != '{}' &&
                data['virtual_accounts'] != '[]') {
              _virtualAccount = data['virtual_accounts'] is String
                  ? jsonDecode(data['virtual_accounts'])
                  : data['virtual_accounts'];
            }
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load account details';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  Future<void> _createVirtualAccount() async {
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
        // Get the created account
        await _getVirtualAccount();
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

        if (mounted) {
          setState(() {
            _virtualAccount = result['account'] ?? result['data'];
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
            if (_isCreatingAccount)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Creating virtual account...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
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
                              'Bank Transfer',
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
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _virtualAccount == null
                    ? _buildCreateAccountView()
                    : _buildAccountDetailsView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateAccountView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance,
                  size: 80,
                  color: AppColors.primary.withOpacity(0.3),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No Virtual Account',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create a virtual account to receive funds via bank transfer',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCreatingAccount
                        ? null
                        : _createVirtualAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Create Virtual Account',
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
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountDetailsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructions Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Transfer money to this account to fund your wallet automatically',
                    style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Account Details Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAccountField(
                  'Bank Name',
                  _virtualAccount!['bank'] ?? 'N/A',
                ),
                const SizedBox(height: 20),
                _buildAccountField(
                  'Account Number',
                  _virtualAccount!['account_number'] ?? 'N/A',
                  showCopy: true,
                ),
                const SizedBox(height: 20),
                _buildAccountField(
                  'Account Name',
                  _virtualAccount!['account_name'] ?? 'N/A',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Refresh Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _loadUserData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Account Details'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountField(
    String label,
    String value, {
    bool showCopy = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            if (showCopy)
              IconButton(
                onPressed: () => _copyToClipboard(value, label),
                icon: Icon(Icons.copy, color: AppColors.primary, size: 20),
                tooltip: 'Copy $label',
              ),
          ],
        ),
      ],
    );
  }
}
