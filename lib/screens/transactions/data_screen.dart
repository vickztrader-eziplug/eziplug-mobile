import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/utils/constants.dart';
import '../../core/theme/app_colors.dart';
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

        // Handle different response structures
        final networksData = data['results']?['data'] ?? data['data'] ?? data;

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

        if (result['results'] != null) {
          if (mounted) {
            setState(() {
              _dataPlans = List<Map<String, dynamic>>.from(
                result['results']['data'] ?? [],
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

      // Check if the API response has success field
      final isSuccess = responseData['success'] == true;

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
      // Show error message without "Exception: " prefix
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
                                  'Data Purchase',
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
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildLabel('Phone Number'),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 80),
                                      Expanded(
                                        flex: 1,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              height: 25,
                                              child: TextButton(
                                                onPressed: _selectContact,
                                                style: TextButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.primary,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          5,
                                                        ),
                                                    side: const BorderSide(
                                                      color:
                                                          AppColors.lightGrey,
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
                                          ],
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Select Network
                      _buildLabel('Select Network'),
                      const SizedBox(height: 12),
                      _isFetchingNetworks
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: _networks.map((network) {
                                return _buildNetworkCard(
                                  network['id'],
                                  network['name'],
                                  network['color'],
                                  network['assetPath'],
                                );
                              }).toList(),
                            ),
                      const SizedBox(height: 30),

                      // Select Data Plan
                      _buildLabel('Select Data Plan'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.lightGrey.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: _isFetchingPlans
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
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
                                      fontSize: 14,
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

  Widget _buildNetworkCard(
    String id,
    String name,
    Color color,
    String assetPath,
  ) {
    final isSelected = _selectedNetworkId == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedNetworkId = id;
            _selectedNetworkName = name;
          });
          // Fetch data plans when network is selected
          _fetchDataPlans(id);
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
                        Icons.sim_card,
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

  // Widget _buildDataPlanChip(Map<String, dynamic> plan) {
  //   // Use a unique identifier for comparison
  //   final planId = plan['id']?.toString() ?? plan['plan_id']?.toString() ?? '';
  //   final selectedPlanId =
  //       _selectedPlan?['id']?.toString() ??
  //       _selectedPlan?['plan_id']?.toString() ??
  //       '';

  //   final isSelected = planId.isNotEmpty && planId == selectedPlanId;

  //   return GestureDetector(
  //     onTap: () {
  //       setState(() {
  //         _selectedPlan = plan;
  //       });
  //       print('✅ Selected plan: ${plan['data']} - ID: $planId');
  //     },
  //     child: Container(
  //       // Fixed width for consistent sizing
  //       width: 85,
  //       // Fixed height for consistent sizing
  //       height: 90,
  //       padding: const EdgeInsets.all(8),
  //       decoration: BoxDecoration(
  //         color: isSelected ? AppColors.primary : Colors.white,
  //         borderRadius: BorderRadius.circular(8),
  //         border: Border.all(
  //           color: isSelected ? AppColors.primary : Colors.grey.shade300,
  //           width: isSelected ? 2 : 1,
  //         ),
  //         boxShadow: [
  //           BoxShadow(
  //             color: isSelected
  //                 ? AppColors.primary.withOpacity(0.3)
  //                 : Colors.grey.withOpacity(0.1),
  //             blurRadius: isSelected ? 8 : 4,
  //             offset: Offset(0, isSelected ? 4 : 2),
  //           ),
  //         ],
  //       ),
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         crossAxisAlignment: CrossAxisAlignment.center,
  //         children: [
  //           // Data amount with fixed height
  //           SizedBox(
  //             height: 32,
  //             child: Center(
  //               child: Text(
  //                 plan['data']?.toString() ??
  //                     plan['plan_name']?.toString() ??
  //                     'N/A',
  //                 style: TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: FontWeight.bold,
  //                   color: isSelected ? Colors.white : Colors.black87,
  //                   height: 1.2,
  //                 ),
  //                 textAlign: TextAlign.center,
  //                 maxLines: 2,
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //             ),
  //           ),
  //           const SizedBox(height: 4),
  //           // Price
  //           Text(
  //             '₦${plan['amount']?.toString() ?? plan['price']?.toString() ?? '0'}',
  //             style: TextStyle(
  //               fontSize: 11,
  //               color: isSelected ? Colors.white : Colors.green,
  //               fontWeight: FontWeight.w600,
  //             ),
  //             maxLines: 1,
  //             overflow: TextOverflow.ellipsis,
  //           ),
  //           const SizedBox(height: 2),
  //           // Validity with fixed height
  //           SizedBox(
  //             height: 18,
  //             child: Text(
  //               plan['validity']?.toString() ?? '',
  //               style: TextStyle(
  //                 fontSize: 8,
  //                 color: isSelected ? Colors.white70 : Colors.black54,
  //               ),
  //               textAlign: TextAlign.center,
  //               maxLines: 1,
  //               overflow: TextOverflow.ellipsis,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  Widget _buildDataPlanChip(Map<String, dynamic> plan) {
    // Use a unique identifier for comparison
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
        print(
          '✅ Selected plan: ${plan['data'] ?? plan['plan_name']} - ID: $planId - Amount: ${plan['amount'] ?? plan['price']}',
        );
      },
      child: Container(
        // Fixed dimensions
        width: 85,
        height: 92,
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
            // Data amount
            Text(
              plan['data']?.toString() ??
                  plan['plan_name']?.toString() ??
                  'N/A',
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
              '₦${plan['amount']?.toString() ?? plan['price']?.toString() ?? '0'}',
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
              plan['validity']?.toString() ?? '',
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
        style: const TextStyle(fontSize: 14, color: AppColors.textColor),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 14,
            color: AppColors.textColor.withOpacity(0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
