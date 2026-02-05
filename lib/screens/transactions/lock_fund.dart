import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../services/auth_service.dart';
import '../../core/widgets/pin_verification_modal.dart';
import '../../core/widgets/modern_form_widgets.dart';

class LockFundScreen extends StatefulWidget {
  const LockFundScreen({super.key});

  @override
  State<LockFundScreen> createState() => _LockFundScreenState();
}

class _LockFundScreenState extends State<LockFundScreen> {
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  DateTime? _selectedDate;
  int _selectedDays = 30;
  double _walletNaira = 0.0;
  bool _isLoadingWallet = true;
  bool _isLoading = false;

  final List<int> _lockPeriods = [7, 14, 30, 60, 90, 180, 365];

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
    _selectedDate = DateTime.now().add(Duration(days: _selectedDays));
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

      print('Lock Fund - User API response status: ${response.statusCode}');
      print('Lock Fund - User API response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // API unwraps single-element arrays, so data is directly the user object
        final userData = responseData['data'] ?? responseData;
        
        print('Lock Fund - Parsed userData: $userData');
        print('Lock Fund - wallet_naira value: ${userData['wallet_naira']}');

        if (mounted) {
          setState(() {
            _walletNaira =
                double.tryParse(userData['wallet_naira']?.toString() ?? '0') ??
                    0.0;
            _isLoadingWallet = false;
          });
          print('Lock Fund - Set _walletNaira to: $_walletNaira');
        }
      }
    } catch (e) {
      print('Error fetching wallet: $e');
      if (mounted) {
        setState(() => _isLoadingWallet = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ?? DateTime.now().add(Duration(days: _selectedDays)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedDays = picked.difference(DateTime.now()).inDays;
      });
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDateForAPI(DateTime date) {
    String year = date.year.toString();
    String month = date.month.toString().padLeft(2, '0');
    String day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  double _getAmountValue() {
    return double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
  }

  double _getInterestRateValue(int days) {
    if (days >= 365) return 12.0;
    if (days >= 180) return 8.5;
    if (days >= 90) return 6.0;
    if (days >= 60) return 4.5;
    if (days >= 30) return 3.0;
    if (days >= 14) return 2.0;
    return 1.5;
  }

  String _getInterestRate(int days) {
    if (days >= 365) return '12.0% p.a.';
    if (days >= 180) return '8.5% p.a.';
    if (days >= 90) return '6.0% p.a.';
    if (days >= 60) return '4.5% p.a.';
    if (days >= 30) return '3.0% p.a.';
    if (days >= 14) return '2.0% p.a.';
    return '1.5% p.a.';
  }

  double _calculateInterest() {
    final amount = _getAmountValue();
    if (amount <= 0) return 0.0;

    final rate = _getInterestRateValue(_selectedDays);
    final daysInYear = 365.0;
    final interest = (amount * rate * _selectedDays) / (100 * daysInYear);

    return interest;
  }

  double _calculateTotalReturn() {
    return _getAmountValue() + _calculateInterest();
  }

  String _formatBalance(double balance) {
    return balance.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
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

  Future<void> _proceedToPin() async {
    // Validation
    if (_amountController.text.isEmpty) {
      _showSnackBar('Please enter an amount', Colors.red);
      return;
    }

    final amount = _getAmountValue();

    if (amount <= 0) {
      _showSnackBar('Please enter a valid amount', Colors.red);
      return;
    }

    if (amount < 1000) {
      _showSnackBar('Minimum lock amount is ₦1,000', Colors.red);
      return;
    }

    if (amount > _walletNaira) {
      _showSnackBar('Insufficient balance', Colors.red);
      return;
    }

    if (_selectedDate == null) {
      _showSnackBar('Please select an unlock date', Colors.red);
      return;
    }

    // Check auth
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = await authService.getToken();

    if (token == null || token.isEmpty) {
      _showSnackBar('Please login to continue', Colors.red);
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (!mounted) return;

    // Show unified PIN verification modal
    final pin = await PinVerificationModal.show(
      context: context,
      title: 'Confirm Lock',
      subtitle: 'Enter your 4-digit PIN to lock your funds',
      transactionType: 'Lock Funds',
      amount: '₦${_formatBalance(amount)}',
      onForgotPin: () {
        _showSnackBar(
            'Go to Profile > PIN Management to reset your PIN', Colors.orange);
      },
    );

    if (pin != null && pin.length == 4) {
      _lockFunds(pin);
    }
  }

  Future<void> _lockFunds(String pin) async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final amount = _getAmountValue();
      // Send the annual interest RATE, not the calculated interest amount
      final interestRate = _getInterestRateValue(_selectedDays);

      final payload = {
        'amount': amount,
        'interest': interestRate,
        'date': _formatDateForAPI(_selectedDate!),
        'pin': pin,
      };

      print('Lock fund payload: $payload');

      final response = await http.post(
        Uri.parse(Constants.lockFund),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);
      print('Lock fund response: $responseData');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh wallet balance
        _fetchWalletBalance();

        // Show success dialog
        _showSuccessDialog(
          responseData['message'] ?? 'Funds locked successfully',
          amount,
        );
      } else if (response.statusCode == 401) {
        _showSnackBar('Session expired. Please login again', Colors.red);
        await authService.logout();
      } else if (response.statusCode == 400 &&
          responseData['message']?.toString().toLowerCase().contains('pin') ==
              true) {
        _showSnackBar(responseData['message'] ?? 'Invalid PIN', Colors.red);
      } else {
        _showSnackBar(
          responseData['message'] ?? 'Failed to lock funds',
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

  void _showSuccessDialog(String message, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Success!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '₦${_formatBalance(amount)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Locked until ${_formatDate(_selectedDate!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pushReplacementNamed(context, '/lockFundHistory');
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'View History',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Go back to previous screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.primary,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                // Header Section
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Column(
                        children: [
                          // App Bar
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Lock Funds',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.history_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: () => Navigator.pushNamed(context, '/lockFundHistory'),
                              tooltip: 'Lock History',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Wallet Balance
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
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
                                    '₦${_formatBalance(_walletNaira)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
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

            // Content Section
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                transform: Matrix4.translationValues(0, -20, 0),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amount Input Card
                        ModernFormWidgets.buildFormCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ModernFormWidgets.buildSectionLabel(
                                'Amount to Lock',
                                icon: Icons.lock_outline_rounded,
                                iconColor: AppColors.primary,
                              ),
                              const SizedBox(height: 12),
                              ModernFormWidgets.buildTextField(
                                controller: _amountController,
                                hintText: 'Enter amount (Min: ₦1,000)',
                                prefixIcon: Icons.payments_outlined,
                                keyboardType: TextInputType.number,
                                onChanged: (value) => setState(() {}),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Lock Period Card
                        ModernFormWidgets.buildFormCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ModernFormWidgets.buildSectionLabel(
                                'Select Lock Period',
                                icon: Icons.schedule_rounded,
                                iconColor: AppColors.primary,
                              ),
                              const SizedBox(height: 12),
                              _buildLockPeriodSelector(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Date Picker Card
                        ModernFormWidgets.buildFormCard(
                          child: _buildDatePicker(),
                        ),
                        const SizedBox(height: 16),

                        // Info Card
                        _buildInfoCard(),
                        const SizedBox(height: 16),

                        // Interest Rate & ROI Card
                        ModernFormWidgets.buildFormCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ModernFormWidgets.buildSectionLabel(
                                'Earnings Summary',
                                icon: Icons.analytics_outlined,
                                iconColor: AppColors.success,
                              ),
                              const SizedBox(height: 16),
                              _buildInterestRateRow(),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Divider(height: 1),
                              ),
                              _buildSummaryRow(
                                'Principal Amount',
                                '₦${_formatBalance(_getAmountValue())}',
                                AppColors.textColor,
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryRow(
                                'Interest Earned',
                                '+₦${_formatBalance(_calculateInterest())}',
                                AppColors.success,
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Divider(height: 1),
                              ),
                              _buildSummaryRow(
                                'Total Return',
                                '₦${_formatBalance(_calculateTotalReturn())}',
                                AppColors.primary,
                                isTotal: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Lock Button
                        _buildLockButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // Loading Overlay
      if (_isLoading)
        Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Locking Funds...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we process your request',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildInterestRateRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Interest Rate',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
          Text(
            _getInterestRate(_selectedDays),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockPeriodSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _lockPeriods.map((days) {
        final isSelected = _selectedDays == days;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDays = days;
              _selectedDate = DateTime.now().add(Duration(days: days));
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.lightGrey,
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '$days days',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _selectDate,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock Date',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textColor.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedDate != null
                      ? _formatDate(_selectedDate!)
                      : _formatDate(
                          DateTime.now().add(Duration(days: _selectedDays))),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textColor.withOpacity(0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Locked funds cannot be withdrawn until the unlock date. Interest is calculated based on the lock period.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textColor.withOpacity(0.7),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor,
      {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 15 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
            color: AppColors.textColor.withOpacity(isTotal ? 1 : 0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 15,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildLockButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _proceedToPin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          disabledBackgroundColor: AppColors.lightGrey,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 20, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Lock Funds',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
