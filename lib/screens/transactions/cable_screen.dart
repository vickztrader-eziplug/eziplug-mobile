import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/api_response.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../services/auth_service.dart';
import '../reusable/pin_entry_screen.dart';
import '../reusable/receipt_screen.dart';

class CableScreen extends StatefulWidget {
  const CableScreen({super.key});

  @override
  State<CableScreen> createState() => _CableScreenState();
}

class _CableScreenState extends State<CableScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _iucController = TextEditingController();

  // Store both id (for plan fetching) and identifier (for verification/purchase)
  int? _selectedProviderId; // Numeric ID for plan fetching
  String? _selectedProviderIdentifier; // String identifier for verification
  String? _selectedProviderName;

  int? _selectedPlanId; // Plan ID for purchase
  String? _selectedPlanName;
  int? _selectedPlanAmount;

  bool _isLoading = false;
  bool _isFetchingProviders = false;
  bool _isFetchingPlans = false;
  bool _isVerifyingIUC = false;
  bool _isLoadingWallet = true;

  String? _customerName;
  String? _iucVerificationError;
  double _walletNaira = 0.0;

  List<Map<String, dynamic>> _providers = [];
  List<Map<String, dynamic>> _plans = [];

  // Default provider images as fallback
  final Map<String, String> _defaultProviderImages = {
    'GOTV': 'assets/images/gotv.png',
    'DSTV': 'assets/images/dstv.png',
    'STARTIMES': 'assets/images/startimes.png',
    'SHOWMAX': 'assets/images/showmax.png',
  };

  final Map<String, Color> _defaultProviderColors = {
    'GOTV': Colors.white,
    'DSTV': Colors.blue,
    'STARTIMES': Colors.white,
    'SHOWMAX': Colors.red,
  };

  @override
  void dispose() {
    _phoneController.dispose();
    _iucController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _fetchWalletBalance();
    _fetchProviders();
    _iucController.addListener(_onIUCNumberChanged);
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
        final responseData = jsonDecode(response.body);
        // API returns: { "success": true, "data": { wallet_naira: ... } }
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
        Uri.parse(Constants.cables),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Cable providers response: $data');
        final providersData = getResponseData(data);

        if (mounted) {
          setState(() {
            // Extract cable providers - store BOTH id and identifier
            _providers = (providersData is List ? providersData : (providersData['data'] ?? providersData ?? []))
                .map<Map<String, dynamic>>(
                  (provider) => {
                    'id': provider['id'], // Numeric ID for plan fetching
                    'identifier':
                        provider['identifier'] ??
                        provider['serviceID'] ??
                        '', // String for verification
                    'name': (provider['name'] as String).toUpperCase(),
                    'color': _getProviderColor(provider['name']),
                    'assetPath': _getProviderAsset(provider['name']),
                  },
                )
                .toList();

            print('Parsed providers: $_providers');
          });
        }
      }
    } catch (e) {
      print('Error fetching providers: $e');
      // Set default providers if API fails
      if (mounted) {
        setState(() {
          _providers = [
            {
              'id': 1,
              'identifier': 'dstv',
              'name': 'DSTV',
              'color': _defaultProviderColors['DSTV']!,
              'assetPath': 'assets/images/dstv.png',
            },
            {
              'id': 2,
              'identifier': 'gotv',
              'name': 'GOTV',
              'color': _defaultProviderColors['GOTV']!,
              'assetPath': 'assets/images/gotv.png',
            },
            {
              'id': 3,
              'identifier': 'startimes',
              'name': 'STARTIMES',
              'color': _defaultProviderColors['STARTIMES']!,
              'assetPath': 'assets/images/startimes.png',
            },
            {
              'id': 4,
              'identifier': 'showmax',
              'name': 'SHOWMAX',
              'color': _defaultProviderColors['SHOWMAX']!,
              'assetPath': 'assets/images/showmax.png',
            },
          ];
        });
      }
    } finally {
      if (mounted) setState(() => _isFetchingProviders = false);
    }
  }

  Future<void> _fetchPlans(int providerId) async {
    setState(() {
      _isFetchingPlans = true;
      _plans = [];
      _selectedPlanId = null;
      _selectedPlanName = null;
      _selectedPlanAmount = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      // Use numeric ID for plan fetching
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/vtu/cable-plans/$providerId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('📡 Plans Response Status: ${response.statusCode}');
      print('📦 Plans Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final plansResponseData = getResponseData(data);

        if (mounted) {
          setState(() {
            // Extract plans data using helper
            dynamic plansData = plansResponseData;

            // Handle both single object and array responses
            List<dynamic> plansList;
            if (plansData is List) {
              // Already an array
              plansList = plansData;
              print('📋 Plans data is a List with ${plansList.length} items');
            } else if (plansData is Map) {
              // Single object - wrap in array
              plansList = [plansData];
              print('📋 Plans data is a single Map, wrapped in List');
            } else {
              plansList = [];
              print('❌ Plans data is neither List nor Map');
            }

            // Parse each plan
            _plans = plansList
                .map<Map<String, dynamic>>(
                  (plan) => {
                    'id': plan['id'], // Plan ID for purchase
                    'name': plan['name']?.toString() ?? '',
                    'code': plan['code']?.toString() ?? '',
                    'amount':
                        double.tryParse(
                          plan['amount']?.toString() ?? '0',
                        )?.toInt() ??
                        0,
                    'buy_price':
                        double.tryParse(
                          plan['buy_price']?.toString() ?? '0',
                        )?.toInt() ??
                        0,
                    'validity': '1 month', // Default since not in API
                  },
                )
                .toList();

            print(
              '✅ Loaded ${_plans.length} cable plans: ${_plans.map((p) => p['name']).toList()}',
            );
          });
        }
      } else {
        print(
          '❌ Failed to fetch plans: ${response.statusCode} - ${response.body}',
        );
        if (mounted) {
          _showSnackBar('Failed to load plans', Colors.red);
        }
      }
    } catch (e) {
      print('❌ Error fetching plans: $e');
      if (mounted) {
        _showSnackBar('Error loading plans: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isFetchingPlans = false);
    }
  }

  Future<void> _purchaseCable(String pin) async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      // Use the correct payload format for cable purchase (NO PIN)
      final payload = {
        'planID': _selectedPlanId, // Plan ID
        'billersCode': _iucController.text, // IUC Number
        'phone': _phoneController.text, // Phone Number
      };

      print('📤 Purchase Payload: $payload');

      final response = await http.post(
        Uri.parse(Constants.cable),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
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
              subtitle: 'Your cable subscription was successful',
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
                  label: 'Customer Name',
                  value: _customerName ?? '',
                ),
                ReceiptDetail(label: 'IUC Number', value: _iucController.text),
                ReceiptDetail(label: 'Plan', value: _selectedPlanName ?? ''),
                ReceiptDetail(
                  label: 'Phone Number',
                  value: _phoneController.text,
                ),
                ReceiptDetail(
                  label: 'Amount',
                  value: '₦${_selectedPlanAmount?.toString() ?? '0'}',
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
      // Show error message without "Exception: " prefix
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
      rethrow;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getProviderColor(String name) {
    final upperName = name.toUpperCase();
    return _defaultProviderColors[upperName] ?? AppColors.primary;
  }

  String _getProviderAsset(String name) {
    final upperName = name.toUpperCase();
    return _defaultProviderImages[upperName] ?? 'assets/images/default.png';
  }

  void _onIUCNumberChanged() {
    final iucNumber = _iucController.text;

    // Verify IUC when it reaches typical length (10-12 digits)
    if (iucNumber.length >= 10 && iucNumber.length <= 12) {
      if (_selectedProviderIdentifier != null) {
        _verifyIUCNumber();
      }
    } else {
      // Clear verification when IUC number changes
      if (_customerName != null || _iucVerificationError != null) {
        setState(() {
          _customerName = null;
          _iucVerificationError = null;
        });
      }
    }
  }

  Future<void> _verifyIUCNumber() async {
    if (_isVerifyingIUC) return;

    setState(() {
      _isVerifyingIUC = true;
      _customerName = null;
      _iucVerificationError = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final payload = {
        'billersCode': _iucController.text,
        'serviceID': _selectedProviderIdentifier,
        'type': _selectedProviderIdentifier,
      };

      print('Verification payload: $payload');

      final response = await http.post(
        Uri.parse(Constants.validate),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);
      print('Verification response: $data');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final verifyData = getResponseData(data);
        setState(() {
          _customerName =
              verifyData?['content']?['Customer_Name'] ??
              verifyData?['Customer_Name'] ??
              data['customer_name'] ??
              data['customerName'] ??
              data['name'] ??
              'Verified';
          _iucVerificationError = null;
        });
        print('Customer verified: $_customerName');
      } else {
        setState(() {
          _customerName = null;
          _iucVerificationError = data['message'] ?? 'Invalid IUC number';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _customerName = null;
        _iucVerificationError = 'Could not verify IUC number';
      });
      print('Verification error: $e');
    } finally {
      if (mounted) setState(() => _isVerifyingIUC = false);
    }
  }

  Future<void> _selectContact() async {
    try {
      // Request permission
      final permissionGranted = await FlutterContacts.requestPermission();

      if (!permissionGranted) {
        _showSnackBar(
          'Contact permission is required to select contacts',
          Colors.orange,
        );
        return;
      }

      // Pick a contact
      final Contact? contact = await FlutterContacts.openExternalPick();

      if (contact != null) {
        // Get the full contact details
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
          _showSnackBar('Contact selected successfully', Colors.green);
        } else {
          _showSnackBar('Selected contact has no phone number', Colors.orange);
        }
      }
    } catch (e) {
      print('Error selecting contact: $e');
      _showSnackBar('Failed to select contact: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _proceedToPin() async {
    // Validation
    if (_phoneController.text.isEmpty) {
      _showSnackBar('Please enter phone number', Colors.red);
      return;
    }

    if (_selectedProviderId == null) {
      _showSnackBar('Please select a cable provider', Colors.red);
      return;
    }

    if (_iucController.text.isEmpty) {
      _showSnackBar('Please enter IUC number', Colors.red);
      return;
    }

    if (_customerName == null) {
      _showSnackBar('Please wait for IUC verification', Colors.red);
      return;
    }

    if (_selectedPlanId == null) {
      _showSnackBar('Please select a plan', Colors.red);
      return;
    }

    // Check wallet balance
    if (_selectedPlanAmount != null && _selectedPlanAmount! > _walletNaira) {
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
          subtitle: 'Enter your 4 digit PIN to purchase cable subscription',
          onPinComplete: (pin) => _purchaseCable(pin),
          onForgotPin: () {
            Navigator.pop(context);
            _showSnackBar('Contact support to reset PIN', Colors.orange);
          },
        ),
      ),
    );
  }

  // Future<void> _purchaseCable(String pin) async {
  //   setState(() => _isLoading = true);

  //   try {
  //     final authService = Provider.of<AuthService>(context, listen: false);
  //     final token = await authService.getToken();

  //     // Use the correct payload format for cable purchase
  //     final payload = {
  //       'planID': _selectedPlanId, // Use plan ID
  //       'billersCode': _iucController.text,
  //       'phone': _phoneController.text,
  //       'pin': pin, // Include PIN for authentication
  //     };

  //     print('Purchase payload: $payload');

  //     final response = await http.post(
  //       Uri.parse(Constants.cable),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Accept': 'application/json',
  //         'Content-Type': 'application/json',
  //       },
  //       body: jsonEncode(payload),
  //     );

  //     final responseData = jsonDecode(response.body);
  //     print('Purchase response: $responseData');

  //     if (!mounted) return;

  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       Navigator.pop(context);

  //       // Refresh wallet balance
  //       _fetchWalletBalance();

  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => ReceiptScreen(
  //             title: 'Purchase Successful',
  //             subtitle: 'Your cable subscription was successful',
  //             details: [
  //               ReceiptDetail(
  //                 label: 'Transaction ID',
  //                 value:
  //                     responseData['transaction_id']?.toString() ??
  //                     responseData['data']?['transaction_id']?.toString() ??
  //                     'N/A',
  //               ),
  //               ReceiptDetail(
  //                 label: 'Provider',
  //                 value: _selectedProviderName ?? '',
  //               ),
  //               ReceiptDetail(
  //                 label: 'Customer Name',
  //                 value: _customerName ?? '',
  //               ),
  //               ReceiptDetail(label: 'IUC Number', value: _iucController.text),
  //               ReceiptDetail(label: 'Plan', value: _selectedPlanName ?? ''),
  //               ReceiptDetail(
  //                 label: 'Phone Number',
  //                 value: _phoneController.text,
  //               ),
  //               ReceiptDetail(
  //                 label: 'Amount',
  //                 value: '₦${_selectedPlanAmount.toString()}',
  //               ),
  //               ReceiptDetail(
  //                 label: 'Date',
  //                 value: DateTime.now().toString().split('.')[0],
  //               ),
  //             ],
  //           ),
  //         ),
  //       );
  //     } else if (response.statusCode == 401) {
  //       Navigator.pop(context); // Close PIN screen
  //       _showSnackBar('Session expired. Please login again', Colors.red);
  //       await authService.logout();
  //     } else if (response.statusCode == 400 &&
  //         responseData['message']?.toString().contains('PIN') == true) {
  //       throw Exception(responseData['message'] ?? 'Invalid PIN');
  //     } else {
  //       Navigator.pop(context);
  //       _showSnackBar(
  //         responseData['message'] ?? 'Failed to purchase cable subscription',
  //         Colors.red,
  //       );
  //     }
  //   } catch (e) {
  //     if (!mounted) return;
  //     _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
  //     rethrow;
  //   } finally {
  //     if (mounted) setState(() => _isLoading = false);
  //   }
  // }

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              // Gradient Header
              ModernFormWidgets.buildGradientHeader(
                context: context,
                title: 'Cable TV',
                walletBalance: _walletNaira,
                isLoadingBalance: _isLoadingWallet,
                primaryColor: isDark ? AppColors.primaryDark : AppColors.primary,
              ),
              
              // Main Content
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
                              icon: Icons.tv,
                              iconColor: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                            const SizedBox(height: 16),
                            _isFetchingProviders
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: CircularProgressIndicator(
                                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : _buildProviderGrid(),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // IUC Number Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'IUC / Smart Card Number',
                              icon: Icons.credit_card,
                              iconColor: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildTextField(
                              controller: _iucController,
                              hintText: 'Enter IUC or Smart Card Number',
                              prefixIcon: Icons.credit_card_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(12),
                              ],
                              suffixWidget: _buildVerifyButton(),
                            ),
                            const SizedBox(height: 8),
                            _buildVerificationStatus(),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Plan Selection Card
                      if (_selectedProviderId != null)
                        ModernFormWidgets.buildFormCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ModernFormWidgets.buildSectionLabel(
                                'Select Plan',
                                icon: Icons.subscriptions,
                                iconColor: isDark ? AppColors.primaryLight : AppColors.primary,
                              ),
                              const SizedBox(height: 12),
                              _buildPlanSelector(),
                            ],
                          ),
                        ),
                      
                      if (_selectedProviderId != null)
                        const SizedBox(height: 16),
                      
                      // Phone Number Card
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ModernFormWidgets.buildSectionLabel(
                                  'Phone Number',
                                  icon: Icons.phone,
                                  iconColor: isDark ? AppColors.primaryLight : AppColors.primary,
                                ),
                                TextButton.icon(
                                  onPressed: _selectContact,
                                  icon: Icon(
                                    Icons.contacts,
                                    size: 16,
                                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                                  ),
                                  label: Text(
                                    'Contacts',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildTextField(
                              controller: _phoneController,
                              hintText: 'Enter phone number',
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
                      
                      // Tip Card
                      ModernFormWidgets.buildInfoCard(
                        message: 'Ensure you enter the correct IUC/Smart Card number. '
                            'The subscription will be activated immediately after payment.',
                        icon: Icons.lightbulb_outline,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Submit Button
                      ModernFormWidgets.buildPrimaryButton(
                        label: 'Subscribe Now',
                        onPressed: _canProceed() ? _proceedToPin : null,
                        isLoading: _isLoading,
                        backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                        icon: Icons.payment,
                      ),
                      
                      const SizedBox(height: 20),
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
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProviderGrid() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: _providers.map((provider) {
        final id = provider['id'] as int;
        final identifier = provider['identifier'] as String;
        final name = provider['name'] as String;
        final assetPath = provider['assetPath'] as String;
        final isSelected = _selectedProviderId == id;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedProviderId = id;
                _selectedProviderIdentifier = identifier;
                _selectedProviderName = name;
                _customerName = null;
                _iucVerificationError = null;
              });
              _fetchPlans(id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.12)
                    : theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? (isDark ? AppColors.primaryLight : AppColors.primary)
                      : (isDark ? const Color(0xFF2D3141) : Colors.grey.shade200),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      assetPath,
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            name.substring(0, 1),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name.length > 8 ? name.substring(0, 8) : name,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? AppColors.primaryLight : AppColors.primary)
                          : theme.textTheme.bodyLarge?.color,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVerifyButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isVerifyingIUC) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          ),
        ),
      );
    }

    return TextButton(
      onPressed: _selectedProviderIdentifier != null &&
              _iucController.text.length >= 10
          ? _verifyIUCNumber
          : null,
      child: Text(
        'Verify',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _selectedProviderIdentifier != null &&
                  _iucController.text.length >= 10
              ? (isDark ? AppColors.primaryLight : AppColors.primary)
              : (isDark ? const Color(0xFF8891A5) : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildVerificationStatus() {
    if (_customerName != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.green.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.green,
                size: 14,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verified',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    _customerName!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_iucVerificationError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.red.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _iucVerificationError!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPlanSelector() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (_isFetchingPlans) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_plans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2D3141) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            'No plans available for this provider',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _plans.map((plan) {
        final id = plan['id'];
        final name = plan['name'] as String;
        final amount = plan['amount'] as int;
        final validity = plan['validity'] as String;
        final isSelected = _selectedPlanId == id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPlanId = id;
              _selectedPlanName = name;
              _selectedPlanAmount = amount;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 90,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.primaryLight : AppColors.primary)
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? (isDark ? AppColors.primaryLight : AppColors.primary)
                    : (isDark ? const Color(0xFF2D3141) : Colors.grey.shade200),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₦${_formatAmount(amount)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : (isDark ? AppColors.primaryLight : AppColors.primary),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  validity,
                  style: TextStyle(
                    fontSize: 8,
                    color: isSelected
                        ? Colors.white70
                        : (isDark ? const Color(0xFF8891A5) : theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatAmount(int amount) {
    return amount
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  bool _canProceed() {
    return _phoneController.text.isNotEmpty &&
        _selectedProviderId != null &&
        _iucController.text.isNotEmpty &&
        _customerName != null &&
        _selectedPlanId != null &&
        !_isLoading;
  }
}
