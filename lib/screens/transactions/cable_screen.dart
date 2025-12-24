import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
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

        if (mounted) {
          setState(() {
            // Extract cable providers - store BOTH id and identifier
            _providers = (data['results']?['data'] ?? data['data'] ?? [])
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

        if (mounted) {
          setState(() {
            // Extract plans data from results.data
            dynamic plansData = data['results']?['data'] ?? data['data'];

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

      // Check if the API response has success field
      final isSuccess =
          responseData['success'] == true || responseData['status'] == true;

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
                  label: 'Provider',
                  value: _selectedProviderName ?? '',
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

  Widget _buildPlanChip(dynamic id, String name, int amount, String validity) {
    final isSelected = _selectedPlanId == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanId = id; // Store plan ID for purchase
          _selectedPlanName = name;
          _selectedPlanAmount = amount;
        });
        print('✅ Selected plan: $name - ID: $id - Amount: $amount');
      },
      child: Container(
        // Fixed dimensions for consistent sizing
        width: 80,
        height: 85,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: isSelected ? 8 : 4,
              offset: Offset(0, isSelected ? 4 : 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Plan name
            Text(
              name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Price
            Text(
              "₦${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}",
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : Colors.green,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Validity
            Text(
              validity,
              style: TextStyle(
                fontSize: 8,
                color: isSelected ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
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
        setState(() {
          _customerName =
              data['results']?['data']?['content']?['Customer_Name'] ??
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
                                  'Cable Purchase',
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
                      // Phone Number
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildLabel('Phone Number'),
                                ),
                                const SizedBox(width: 80),
                                Expanded(
                                  flex: 1,
                                  child: SizedBox(
                                    height: 25,
                                    child: TextButton(
                                      onPressed: _selectContact,
                                      style: TextButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          side: const BorderSide(
                                            color: AppColors.lightGrey,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Select Contact',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.light,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _phoneController,
                              hintText: 'Phone Number',
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Select Cable Provider
                      _buildLabel('Select Cable Provider'),
                      const SizedBox(height: 12),
                      _isFetchingProviders
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: _providers.map((provider) {
                                return _buildProviderCard(
                                  provider['id'],
                                  provider['identifier'],
                                  provider['name'],
                                  provider['color'],
                                  provider['assetPath'],
                                );
                              }).toList(),
                            ),
                      const SizedBox(height: 30),

                      // IUC Number with Verification
                      _buildLabel('IUC Number'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _iucController,
                        hintText: 'Enter IUC number',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),

                      // Verification Status
                      if (_isVerifyingIUC)
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Verifying IUC...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textColor.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),

                      if (_customerName != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Verified',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      _customerName!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_iucVerificationError != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
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
                        ),
                      const SizedBox(height: 30),

                      // Select Plan
                      _buildLabel('Select Plan'),
                      const SizedBox(height: 12),
                      if (_isFetchingPlans)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      else if (_plans.isEmpty && _selectedProviderId != null)
                        const Center(
                          child: Text(
                            'No plans available',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textColor,
                            ),
                          ),
                        )
                      else if (_plans.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: _plans.map((plan) {
                              return _buildPlanChip(
                                plan['id'],
                                plan['name'],
                                plan['amount'],
                                plan['validity'],
                              );
                            }).toList(),
                          ),
                        ),

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

  Widget _buildProviderCard(
    int id,
    String identifier,
    String name,
    Color color,
    String assetPath,
  ) {
    final isSelected = _selectedProviderId == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedProviderId = id; // Store numeric ID
            _selectedProviderIdentifier = identifier; // Store identifier
            _selectedProviderName = name;
            _customerName = null;
            _iucVerificationError = null;
          });
          _fetchPlans(id); // Use numeric ID for plan fetching
          print(
            '✅ Selected provider: $name - ID: $id - Identifier: $identifier',
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.lightGrey.withOpacity(0.5),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    assetPath,
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.tv,
                        color: isSelected ? Colors.white : color,
                        size: 24,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildPlanChip(dynamic id, String name, int amount, String validity) {
  //   final isSelected = _selectedPlanId == id;
  //   return GestureDetector(
  //     onTap: () {
  //       setState(() {
  //         _selectedPlanId = id; // Store plan ID for purchase
  //         _selectedPlanName = name;
  //         _selectedPlanAmount = amount;
  //       });
  //     },
  //     child: Container(
  //       width: 75,
  //       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
  //       decoration: BoxDecoration(
  //         color: isSelected ? AppColors.primary : Colors.white,
  //         borderRadius: BorderRadius.circular(5),
  //         border: Border.all(
  //           color: isSelected ? AppColors.primary : Colors.grey.shade300,
  //           width: isSelected ? 2 : 1,
  //         ),
  //         boxShadow: [
  //           BoxShadow(
  //             color: Colors.grey.withOpacity(0.1),
  //             blurRadius: 4,
  //             offset: const Offset(0, 2),
  //           ),
  //         ],
  //       ),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.center,
  //         children: [
  //           Text(
  //             name,
  //             style: TextStyle(
  //               fontSize: 10,
  //               fontWeight: FontWeight.bold,
  //               color: isSelected ? Colors.white : Colors.black87,
  //             ),
  //             maxLines: 1,
  //             overflow: TextOverflow.ellipsis,
  //           ),
  //           const SizedBox(height: 4),
  //           Text(
  //             "₦$amount",
  //             style: TextStyle(
  //               fontSize: 10,
  //               color: isSelected ? Colors.white : Colors.green,
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //           const SizedBox(height: 4),
  //           Text(
  //             validity,
  //             style: TextStyle(
  //               fontSize: 8,
  //               color: isSelected ? Colors.white70 : Colors.black54,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

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
          counterText: '', // Hide character counter
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
