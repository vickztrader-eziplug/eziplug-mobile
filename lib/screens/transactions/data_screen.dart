import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/api_response.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../services/auth_service.dart';
import '../reusable/pin_entry_screen.dart';
import '../reusable/receipt_screen.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final TextEditingController _phoneController = TextEditingController();

  String? _selectedNetworkId;
  String? _selectedNetworkName;
  Map<String, dynamic>? _selectedPlan;
  bool _isLoading = false;
  bool _isFetchingNetworks = false;
  bool _isFetchingPlans = false;
  double _walletNaira = 0.0;
  bool _isLoadingWallet = true;

  List<Map<String, dynamic>> _networks = [];
  List<Map<String, dynamic>> _dataPlans = [];

  // External link for networks (optional - comment out to use internal API)
  // final String networksExternalUrl = 'https://your-api.com/networks';

  // Default network images as fallback
  final Map<String, String> _defaultNetworkImages = {
    'MTN': 'assets/images/mtn.png',
    'GLO': 'assets/images/glo.png',
    'AIRTEL': 'assets/images/airtel.png',
    '9MOBILE': 'assets/images/9mobile.png',
  };

  final Map<String, Color> _defaultNetworkColors = {
    'MTN': AppColors.primary,
    'GLO': AppColors.primary,
    'AIRTEL': AppColors.primary,
    '9MOBILE': AppColors.primary,
  };

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _fetchWalletBalance();
    _fetchNetworks();
  }

  @override
  void dispose() {
    _phoneController.dispose();
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

  Future<void> _fetchNetworks() async {
    setState(() => _isFetchingNetworks = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      // Option 1: Use external URL (uncomment if needed)
      // final url = networksExternalUrl;

      // Option 2: Use internal API (default)
      final url = '${Constants.baseUrl}/networks';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('📡 Networks Status: ${response.statusCode}');
      print('📦 Networks Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle different response structures using helper
        final networksData = getResponseData(data);

        if (mounted) {
          setState(() {
            _networks =
                (networksData['networks'] ??
                        networksData['data'] ??
                        networksData)
                    .map<Map<String, dynamic>>(
                      (network) => {
                        'id': network['id']?.toString() ?? '',
                        'name': (network['name'] as String).toUpperCase(),
                        'color': _getNetworkColor(network['name']),
                        'assetPath': _getNetworkAsset(network['name']),
                      },
                    )
                    .toList();
          });
        }
      }
    } catch (e) {
      print('Error fetching networks: $e');
      // Set default networks if API fails
      if (mounted) {
        setState(() {
          _networks = [
            {
              'id': '1',
              'name': 'MTN',
              'color': _defaultNetworkColors['MTN']!,
              'assetPath': 'assets/images/mtn.png',
            },
            {
              'id': '4',
              'name': 'GLO',
              'color': _defaultNetworkColors['GLO']!,
              'assetPath': 'assets/images/glo.png',
            },
            {
              'id': '2',
              'name': 'AIRTEL',
              'color': _defaultNetworkColors['AIRTEL']!,
              'assetPath': 'assets/images/airtel.png',
            },
            {
              'id': '3',
              'name': '9MOBILE',
              'color': _defaultNetworkColors['9MOBILE']!,
              'assetPath': 'assets/images/9mobile.png',
            },
          ];
        });
      }
    } finally {
      if (mounted) setState(() => _isFetchingNetworks = false);
    }
  }

  Future<void> _fetchDataPlans(String networkId) async {
    setState(() {
      _isFetchingPlans = true;
      _dataPlans = [];
      _selectedPlan = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/vtu/data/plans/$networkId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      print('📡 Data Plans Status: ${response.statusCode}');
      print('📦 Data Plans Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final plansData = getResponseData(result);

        if (plansData != null) {
          if (mounted) {
            setState(() {
              _dataPlans = List<Map<String, dynamic>>.from(
                plansData is List ? plansData : (plansData['data'] ?? plansData ?? []),
              );
              print('✅ Loaded ${_dataPlans.length} data plans');
            });
          }
        } else {
          _showSnackBar(
            'No data plans available for this network',
            Colors.orange,
          );
        }
      } else {
        _showSnackBar('Failed to load data plans', Colors.red);
      }
    } catch (e) {
      print('Error fetching data plans: $e');
      _showSnackBar('Error loading data plans', Colors.red);
    } finally {
      if (mounted) setState(() => _isFetchingPlans = false);
    }
  }

  Color _getNetworkColor(String name) {
    final upperName = name.toUpperCase();
    return _defaultNetworkColors[upperName] ?? AppColors.primary;
  }

  String _getNetworkAsset(String name) {
    final upperName = name.toUpperCase();
    return _defaultNetworkImages[upperName] ?? 'assets/images/default.png';
  }

  Future<void> _selectContact() async {
    if (await FlutterContacts.requestPermission()) {
      final Contact? contact = await FlutterContacts.openExternalPick();

      if (contact != null) {
        final Contact? fullContact = await FlutterContacts.getContact(
          contact.id,
        );

        if (fullContact != null && fullContact.phones.isNotEmpty) {
          setState(() {
            String phoneNumber = fullContact.phones.first.number.replaceAll(
              RegExp(r'[^\d+]'),
              '',
            );
            _phoneController.text = phoneNumber;
          });
        }
      }
    } else {
      _showSnackBar('Contact permission denied', Colors.red);
    }
  }

  Future<void> _proceedToPin() async {
    // Validation
    if (_phoneController.text.isEmpty) {
      _showSnackBar('Please enter phone number', Colors.red);
      return;
    }

    if (_selectedNetworkId == null) {
      _showSnackBar('Please select a network', Colors.red);
      return;
    }

    if (_selectedPlan == null) {
      _showSnackBar('Please select a data plan', Colors.red);
      return;
    }

    // Check balance
    final planAmount =
        double.tryParse(
          _selectedPlan!['amount']?.toString() ??
              _selectedPlan!['price']?.toString() ??
              '0',
        ) ??
        0.0;
    if (planAmount > _walletNaira) {
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
          subtitle: 'Enter your 4 digit PIN to buy data',
          onPinComplete: (pin) => _purchaseData(pin),
          onForgotPin: () {
            Navigator.pop(context);
            _showSnackBar('Contact support to reset PIN', Colors.orange);
          },
        ),
      ),
    );
  }

  Future<void> _purchaseData(String pin) async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/vtu/data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'plan_id':
              _selectedPlan!['id']?.toString() ??
              _selectedPlan!['plan_id']?.toString(),
          'phone': _phoneController.text.trim(),
        }),
      );

      final responseData = jsonDecode(response.body);

      if (!mounted) return;
      print('📡 Purchase Response Status: ${response.statusCode}');
      print('📦 Purchase Response Data: $responseData');

      // Check for session expiration first
      if (response.statusCode == 401) {
        Navigator.pop(context); // Close PIN screen
        _showSnackBar('Session expired. Please login again', Colors.red);
        await authService.logout();
        return;
      }

      // Check if the API response has success field (handles both formats)
      final isSuccess = isSuccessResponse(responseData);

      if (isSuccess) {
        // Success: Close PIN screen and show receipt
        Navigator.pop(context);

        // Refresh wallet balance
        await _fetchWalletBalance();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              title: 'Purchase Successful',
              subtitle: 'Your data purchase was successful',
              details: [
                ReceiptDetail(
                  label: 'Transaction ID',
                  value:
                      responseData['transaction_id']?.toString() ??
                      responseData['reference']?.toString() ??
                      responseData['data']?['transaction_id']?.toString() ??
                      responseData['data']?['reference']?.toString() ??
                      'N/A',
                ),
                ReceiptDetail(
                  label: 'Network',
                  value: _selectedNetworkName ?? '',
                ),
                ReceiptDetail(
                  label: 'Phone Number',
                  value: _phoneController.text,
                ),
                ReceiptDetail(
                  label: 'Data Plan',
                  value:
                      _selectedPlan!['data']?.toString() ??
                      _selectedPlan!['plan_name']?.toString() ??
                      _selectedPlan!['name']?.toString() ??
                      '',
                ),
                ReceiptDetail(
                  label: 'Amount',
                  value:
                      '₦${_selectedPlan!['amount']?.toString() ?? _selectedPlan!['price']?.toString()}',
                ),
                ReceiptDetail(
                  label: 'Validity',
                  value: _selectedPlan!['validity']?.toString() ?? 'N/A',
                ),
                ReceiptDetail(
                  label: 'Date',
                  value: DateTime.now().toString().split('.')[0],
                ),
              ],
            ),
          ),
        );
      } else {
        // Failure: Check if it's a PIN error (don't close PIN screen)
        final errorMessage =
            responseData['message']?.toString() ?? 'Something went wrong';

        if (errorMessage.toLowerCase().contains('pin')) {
          // PIN error - keep PIN screen open and show error
          throw Exception(errorMessage);
        } else {
          // Other errors - close PIN screen and show error
          Navigator.pop(context);
          _showSnackBar(errorMessage, Colors.red);
        }
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
              // Modern Gradient Header
              ModernFormWidgets.buildGradientHeader(
                context: context,
                title: 'Buy Data',
                walletBalance: _walletNaira,
                isLoadingBalance: _isLoadingWallet,
                primaryColor: AppColors.dataColor,
              ),
              
              // Content Section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Network Selection
                      ModernFormWidgets.buildSectionLabel('Select Network', icon: Icons.sim_card_outlined, iconColor: AppColors.dataColor),
                      const SizedBox(height: 12),
                      ModernFormWidgets.buildNetworkGrid(
                        networks: _networks,
                        selectedId: _selectedNetworkId,
                        onSelect: (id, name) {
                          setState(() {
                            _selectedNetworkId = id;
                            _selectedNetworkName = name;
                          });
                          _fetchDataPlans(id);
                        },
                        isLoading: _isFetchingNetworks,
                      ),
                      
                      const SizedBox(height: 24),

                      // Phone Number Input
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ModernFormWidgets.buildSectionLabel('Phone Number', icon: Icons.phone_android, iconColor: AppColors.dataColor),
                                TextButton.icon(
                                  onPressed: _selectContact,
                                  icon: Icon(Icons.contacts, size: 16, color: AppColors.dataColor),
                                  label: Text(
                                    'Contacts',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.dataColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    backgroundColor: AppColors.dataColor.withOpacity(0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildTextField(
                              controller: _phoneController,
                              hintText: 'Enter phone number',
                              prefixIcon: Icons.phone,
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // Data Plan Selection
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel('Select Data Plan', icon: Icons.wifi_rounded, iconColor: AppColors.dataColor),
                            const SizedBox(height: 14),
                            _isFetchingPlans
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20.0),
                                  child: CircularProgressIndicator(
                                    color: AppColors.dataColor,
                                  ),
                                ),
                              )
                            : _dataPlans.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Text(
                                    _selectedNetworkId == null
                                        ? 'Select a network to view plans'
                                        : 'No data plans available',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            : Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _dataPlans.map((plan) {
                                  return _buildDataPlanChip(plan);
                                }).toList(),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Info tip
                      ModernFormWidgets.buildInfoCard(
                        message: 'Data will be credited instantly to the phone number provided.',
                        icon: Icons.info_outline,
                        color: AppColors.dataColor,
                      ),

                      const SizedBox(height: 24),

                      // Proceed Button
                      ModernFormWidgets.buildPrimaryButton(
                        label: 'Buy Data',
                        onPressed: _proceedToPin,
                        isLoading: _isLoading,
                        backgroundColor: AppColors.dataColor,
                        icon: Icons.send_rounded,
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
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataPlanChip(Map<String, dynamic> plan) {
    final planId = plan['id']?.toString() ?? plan['plan_id']?.toString() ?? '';
    final selectedPlanId =
        _selectedPlan?['id']?.toString() ??
        _selectedPlan?['plan_id']?.toString() ??
        '';

    final isSelected = planId.isNotEmpty && planId == selectedPlanId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = plan;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.dataColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.dataColor : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.dataColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              plan['data']?.toString() ?? plan['plan_name']?.toString() ?? 'N/A',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.text,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '₦${plan['amount']?.toString() ?? plan['price']?.toString() ?? '0'}',
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : AppColors.success,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (plan['validity'] != null) ...[
              const SizedBox(height: 2),
              Text(
                plan['validity'].toString(),
                style: TextStyle(
                  fontSize: 8,
                  color: isSelected ? Colors.white70 : Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
