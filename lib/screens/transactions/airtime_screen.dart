import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/api_response.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../core/widgets/pin_verification_modal.dart';
import '../../services/auth_service.dart';
import '../reusable/receipt_screen.dart';

class AirtimeScreen extends StatefulWidget {
  const AirtimeScreen({super.key});

  @override
  State<AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends State<AirtimeScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _customAmountController = TextEditingController();

  String? _selectedNetworkId;
  String? _selectedNetworkName;
  int? _selectedAmount;
  bool _isLoading = false;
  bool _isFetchingNetworks = false;
  bool _showCustomAmount = false;
  double _walletNaira = 0.0;
  bool _isLoadingWallet = true;

  List<Map<String, dynamic>> _networks = [];

  // Default network images as fallback
  final Map<String, String> _defaultNetworkImages = {
    'MTN': 'assets/images/mtn.png',
    'GLO': 'assets/images/glo.png',
    'AIRTEL': 'assets/images/airtel.png',
    '9MOBILE': 'assets/images/9mobile.png',
  };

  final Map<String, Color> _defaultNetworkColors = {
    'MTN': AppColors.primary, //const Color.fromARGB(255, 202, 142, 14),
    'GLO': AppColors.primary,
    'AIRTEL': AppColors.primary,
    '9MOBILE': AppColors.primary,
  };

  final List<int> _amounts = [100, 200, 500, 1000, 2000, 3000, 5000, 10000];

  @override
  void dispose() {
    _phoneController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _fetchNetworks();
    _fetchWalletBalance();
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

      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/networks'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        final data = getResponseData(responseJson);

        if (mounted) {
          setState(() {
            // Assuming API returns: {networks: [{id: "1", name: "MTN", ...}]}
            _networks = (data['networks'] ?? data['data'] ?? data ?? [])
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

    // Get amount from selected chip or custom input
    int? amount = _selectedAmount;
    if (amount == null && _customAmountController.text.isNotEmpty) {
      amount = int.tryParse(_customAmountController.text.replaceAll(',', ''));
    }

    if (amount == null || amount <= 0) {
      _showSnackBar('Please select or enter an amount', Colors.red);
      return;
    }

    // Check balance BEFORE showing PIN screen
    if (_walletNaira < amount) {
      _showSnackBar(
        'Insufficient balance (₦${_formatBalance(_walletNaira)}). Please fund your wallet',
        Colors.red,
      );
      return;
    }

    // Check auth right before proceeding to PIN
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();
    print('token: $token');

    if (token == null || token.isEmpty) {
      _showSnackBar('Please login to continue', Colors.red);
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Show PIN verification modal
    if (!mounted) return;

    final pin = await PinVerificationModal.show(
      context: context,
      title: 'Confirm Purchase',
      subtitle: 'Enter your 4-digit PIN to confirm this transaction',
      transactionType: 'Airtime Purchase',
      recipient: _phoneController.text,
      amount: '₦${_formatBalance(amount.toDouble())}',
      onForgotPin: () {
        _showSnackBar('Go to Profile > PIN Management to reset your PIN', Colors.orange);
      },
    );

    if (pin != null && pin.length == 4) {
      _purchaseAirtime(pin);
    }
  }

  Future<void> _purchaseAirtime(String pin) async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      // Get final amount
      int amount =
          _selectedAmount ??
          int.parse(_customAmountController.text.replaceAll(',', ''));

      // Check balance before proceeding
      if (_walletNaira < amount) {
        if (!mounted) return;
        _showSnackBar(
          'Insufficient balance. Please fund your wallet',
          Colors.red,
        );
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/vtu/airtime'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'network_id': _selectedNetworkId,
          'phone': _phoneController.text,
          'amount': amount,
          'pin': pin,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (!mounted) return;
      print('responseData: $responseData');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Update wallet balance after successful purchase
        if (responseData['new_balance'] != null) {
          setState(() {
            _walletNaira =
                double.tryParse(
                  responseData['new_balance']?.toString() ?? '0',
                ) ??
                _walletNaira;
          });
        } else {
          // Fallback: manually deduct if backend doesn't return new balance
          setState(() {
            _walletNaira -= amount;
          });
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              title: 'Purchase Successful',
              subtitle: 'Your airtime purchase was successful',
              details: [
                ReceiptDetail(
                  label: 'Transaction ID',
                  value: responseData['reference']?.toString() ?? 'N/A',
                ),
                ReceiptDetail(
                  label: 'Network',
                  value: _selectedNetworkName ?? '',
                ),
                ReceiptDetail(
                  label: 'Phone Number',
                  value: _phoneController.text,
                ),
                ReceiptDetail(label: 'Amount', value: '₦${amount.toString()}'),
                ReceiptDetail(
                  label: 'New Balance',
                  value: '₦${_formatBalance(_walletNaira)}',
                ),
                ReceiptDetail(
                  label: 'Date',
                  value: DateTime.now().toString().split('.')[0],
                ),
              ],
            ),
          ),
        );
      } else if (response.statusCode == 400) {
        // Check for specific error messages
        if (responseData['message']?.toLowerCase().contains('insufficient') ==
            true) {
          // Refresh wallet balance from server
          await _fetchWalletBalance();
          _showSnackBar(
            'Insufficient funds. Please fund your wallet',
            Colors.red,
          );
        } else if (responseData['message']?.toLowerCase().contains('pin') ==
            true) {
          _showSnackBar(responseData['message'] ?? 'Invalid PIN', Colors.red);
        } else {
          _showSnackBar(
            responseData['message'] ?? 'Transaction failed',
            Colors.red,
          );
        }
      } else if (response.statusCode == 401) {
        _showSnackBar('Session expired. Please login again', Colors.red);
        await authService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _showSnackBar(
          responseData['message'] ?? 'Failed to purchase airtime',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    // Use ToastHelper for consistent top-positioned toasts
    ToastHelper.showSnackBar(context, message, color);
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
                title: 'Buy Airtime',
                walletBalance: _walletNaira,
                isLoadingBalance: _isLoadingWallet,
                primaryColor: AppColors.airtimeColor,
              ),
              
              // Content Section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Network Selection
                      ModernFormWidgets.buildSectionLabel('Select Network', icon: Icons.sim_card_outlined, iconColor: AppColors.airtimeColor),
                      const SizedBox(height: 12),
                      ModernFormWidgets.buildNetworkGrid(
                        networks: _networks,
                        selectedId: _selectedNetworkId,
                        onSelect: (id, name) {
                          setState(() {
                            _selectedNetworkId = id;
                            _selectedNetworkName = name;
                          });
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
                                ModernFormWidgets.buildSectionLabel('Phone Number', icon: Icons.phone_android, iconColor: AppColors.airtimeColor),
                                TextButton.icon(
                                  onPressed: _selectContact,
                                  icon: Icon(Icons.contacts, size: 16, color: AppColors.airtimeColor),
                                  label: Text(
                                    'Contacts',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.airtimeColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    backgroundColor: AppColors.airtimeColor.withOpacity(0.1),
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

                      // Amount Selection
                      ModernFormWidgets.buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ModernFormWidgets.buildSectionLabel('Select Amount', icon: Icons.payments_outlined, iconColor: AppColors.airtimeColor),
                                Row(
                                  children: [
                                    Text(
                                      'Custom',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Transform.scale(
                                      scale: 0.8,
                                      child: Switch(
                                        value: _showCustomAmount,
                                        onChanged: (value) {
                                          setState(() {
                                            _showCustomAmount = value;
                                            if (value) {
                                              _selectedAmount = null;
                                            } else {
                                              _customAmountController.clear();
                                            }
                                          });
                                        },
                                        activeColor: AppColors.airtimeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _showCustomAmount
                                ? ModernFormWidgets.buildTextField(
                                    controller: _customAmountController,
                                    hintText: 'Enter amount',
                                    prefixIcon: Icons.monetization_on_outlined,
                                    keyboardType: TextInputType.number,
                                  )
                                : ModernFormWidgets.buildAmountGrid(
                                    amounts: _amounts,
                                    selectedAmount: _selectedAmount,
                                    onSelect: (amount) {
                                      setState(() {
                                        _selectedAmount = amount;
                                        _customAmountController.clear();
                                      });
                                    },
                                  ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Info tip
                      ModernFormWidgets.buildInfoCard(
                        message: 'Airtime will be credited instantly to the phone number provided.',
                        icon: Icons.info_outline,
                        color: AppColors.airtimeColor,
                      ),

                      const SizedBox(height: 24),

                      // Proceed Button
                      ModernFormWidgets.buildPrimaryButton(
                        label: 'Buy Airtime',
                        onPressed: _proceedToPin,
                        isLoading: _isLoading,
                        backgroundColor: AppColors.airtimeColor,
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

  String _formatBalance(double balance) {
    return balance
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
