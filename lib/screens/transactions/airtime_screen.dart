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

      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/networks'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['results']['data'];

        if (mounted) {
          setState(() {
            // Assuming API returns: {networks: [{id: "1", name: "MTN", ...}]}
            _networks = (data['networks'] ?? data['data'] ?? [])
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

    // Navigate to PIN screen
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinEntryScreen(
          title: 'Confirm Purchase',
          subtitle: 'Enter your 4 digit PIN to buy ₦$amount airtime',
          onPinComplete: (pin) => _purchaseAirtime(pin),
          onForgotPin: () {
            Navigator.pop(context);
            _showSnackBar('Contact support to reset PIN', Colors.orange);
          },
        ),
      ),
    );
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
        Navigator.pop(context); // Close PIN screen
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

        Navigator.pop(context); // Close PIN screen

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
        Navigator.pop(context); // Close PIN screen

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
          // Don't close PIN screen for invalid PIN - let user retry
          return;
        } else {
          _showSnackBar(
            responseData['message'] ?? 'Transaction failed',
            Colors.red,
          );
        }
      } else if (response.statusCode == 401) {
        Navigator.pop(context); // Close PIN screen
        _showSnackBar('Session expired. Please login again', Colors.red);
        await authService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        Navigator.pop(context);
        _showSnackBar(
          responseData['message'] ?? 'Failed to purchase airtime',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close PIN screen
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
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
                                  'Airtime Purchase',
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

                      // Select or Input
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('Select /Input Amount'),
                          Row(
                            children: [
                              Text(
                                'Custom',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textColor.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: _showCustomAmount,
                                onChanged: (value) {
                                  setState(() {
                                    _showCustomAmount = value;
                                    if (value) {
                                      _selectedAmount =
                                          null; // Clear preset selection
                                    } else {
                                      _customAmountController
                                          .clear(); // Clear custom input
                                    }
                                  });
                                },
                                activeColor: AppColors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _showCustomAmount
                            ? _buildTextField(
                                controller: _customAmountController,
                                hintText: 'Enter custom amount',
                                keyboardType: TextInputType.number,
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _amounts.map((amount) {
                                  return _buildAmountChip(amount);
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

  Widget _buildAmountChip(int amount) {
    final isSelected = _selectedAmount == amount;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAmount = amount;
          _customAmountController
              .clear(); // Clear custom input when chip is selected
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.light,
            width: 1,
          ),
        ),
        child: Text(
          '₦$amount',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textColor,
          ),
        ),
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
