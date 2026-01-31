import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../services/auth_service.dart';
import '../reusable/pin_entry_screen.dart';
import '../reusable/receipt_screen.dart';

class BettingScreen extends StatefulWidget {
  const BettingScreen({super.key});

  @override
  State<BettingScreen> createState() => _BettingScreenState();
}

class _BettingScreenState extends State<BettingScreen> {
  // Betting theme color
  static const Color _accentColor = Color(0xFF00BCD4);
  
  final TextEditingController _bettingIdController = TextEditingController();

  List<Map<String, dynamic>> _providers = [];
  Map<String, dynamic>? _selectedProvider;
  int? _selectedAmount;
  bool _isLoading = false;
  bool _isFetchingProviders = false;
  double _walletNaira = 0.0;
  bool _isLoadingWallet = true;

  final List<int> _amounts = [
    500,
    1000,
    1500,
    2000,
    2500,
    3000,
    3500,
    4000,
    5000,
    10000,
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _fetchProviders();
    _fetchWalletBalance();
  }

  @override
  void dispose() {
    _bettingIdController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();

    if ((token == null || token.isEmpty) && mounted) {
      print('Not authenticated: $token');
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
        Uri.parse(Constants.user),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      print('Wallet: $response');
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
        Uri.parse(Constants.bettingCategories),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('📡 Providers Status: ${response.statusCode}');
      print('📦 Providers Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['categories'] != null) {
          if (mounted) {
            setState(() {
              _providers = List<Map<String, dynamic>>.from(
                result['categories'],
              );
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching providers: $e');
      // Set default providers if API fails
      if (mounted) {
        setState(() {
          _providers = [
            {'id': 1, 'name': 'Bet9ja', 'code': 'bet9ja'},
            {'id': 2, 'name': 'NairaBet', 'code': 'nairabet'},
            {'id': 3, 'name': 'BetKing', 'code': 'betking'},
            {'id': 4, 'name': 'MerryBet', 'code': 'merrybet'},
          ];
        });
      }
    } finally {
      if (mounted) setState(() => _isFetchingProviders = false);
    }
  }

  Future<void> _proceedToPin() async {
    // Validation
    if (_bettingIdController.text.isEmpty) {
      _showSnackBar('Please enter betting ID', Colors.red);
      return;
    }

    if (_selectedProvider == null) {
      _showSnackBar('Please select a provider', Colors.red);
      return;
    }

    if (_selectedAmount == null || _selectedAmount! <= 0) {
      _showSnackBar('Please select an amount', Colors.red);
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
          subtitle: 'Enter your 4 digit PIN to purchase bet',
          onPinComplete: (pin) => _purchaseBet(pin),
          onForgotPin: () {
            Navigator.pop(context);
            _showSnackBar('Contact support to reset PIN', Colors.orange);
          },
        ),
      ),
    );
  }

  Future<void> _purchaseBet(String pin) async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/betting/purchase'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'provider_id': _selectedProvider!['id'],
          'betting_id': _bettingIdController.text.trim(),
          'amount': _selectedAmount,
          'pin': pin,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (!mounted) return;
      print('Response Data: $responseData');

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context); // Close PIN screen

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              title: 'Purchase Successful',
              subtitle: 'Your bet purchase was successful',
              details: [
                ReceiptDetail(
                  label: 'Transaction ID',
                  value:
                      responseData['transaction_id'] ??
                      responseData['reference'] ??
                      'N/A',
                ),
                ReceiptDetail(
                  label: 'Provider',
                  value: _selectedProvider!['name'] ?? '',
                ),
                ReceiptDetail(
                  label: 'Betting ID',
                  value: _bettingIdController.text,
                ),
                ReceiptDetail(
                  label: 'Amount',
                  value: '₦${_selectedAmount.toString()}',
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
          responseData['message']?.contains('PIN') == true) {
        throw Exception(responseData['message'] ?? 'Invalid PIN');
      } else {
        Navigator.pop(context);
        _showSnackBar(
          responseData['message'] ?? 'Failed to purchase bet',
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              // Modern Gradient Header
              ModernFormWidgets.buildGradientHeader(
                context: context,
                title: 'Betting',
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
                      // Provider Selection Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Select Provider',
                              icon: Icons.sports_esports,
                              iconColor: _accentColor,
                            ),
                            const SizedBox(height: 12),
                            _isFetchingProviders
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _accentColor,
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: DropdownButtonFormField<Map<String, dynamic>>(
                                      value: _selectedProvider,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _accentColor),
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.casino, color: _accentColor, size: 20),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      hint: Text(
                                        'Select a betting provider',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 13,
                                        ),
                                      ),
                                      items: _providers.map((provider) {
                                        return DropdownMenuItem<Map<String, dynamic>>(
                                          value: provider,
                                          child: Text(
                                            provider['name'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() => _selectedProvider = value);
                                      },
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Betting ID Input Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Betting ID',
                              icon: Icons.confirmation_number,
                              iconColor: _accentColor,
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildTextField(
                              controller: _bettingIdController,
                              hintText: 'Enter your betting account ID',
                              prefixIcon: Icons.person_outline,
                              keyboardType: TextInputType.text,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Amount Selection Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Select Amount',
                              icon: Icons.payments,
                              iconColor: _accentColor,
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildAmountGrid(
                              amounts: _amounts,
                              selectedAmount: _selectedAmount,
                              onSelect: (amount) {
                                setState(() => _selectedAmount = amount);
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Info Card
                      ModernFormWidgets.buildInfoCard(
                        message: 'Fund your betting wallet instantly. Ensure your betting ID is correct before proceeding.',
                        icon: Icons.lightbulb_outline,
                        color: _accentColor,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Primary Action Button
                      ModernFormWidgets.buildPrimaryButton(
                        label: 'Fund Betting Account',
                        onPressed: _proceedToPin,
                        isLoading: _isLoading,
                        backgroundColor: _accentColor,
                        icon: Icons.send,
                      ),
                      
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
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

  String _formatBalance(double balance) {
    return balance
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
