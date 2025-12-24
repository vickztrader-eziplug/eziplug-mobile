import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../services/auth_service.dart';
import '../reusable/pin_entry_screen.dart';
import 'lock_fund.dart';

class SaveAndEarnScreen extends StatefulWidget {
  const SaveAndEarnScreen({super.key});

  @override
  State<SaveAndEarnScreen> createState() => _SaveAndEarnScreenState();
}

class _SaveAndEarnScreenState extends State<SaveAndEarnScreen> {
  final TextEditingController _withdrawAmountController =
      TextEditingController();

  double _walletNaira = 0.0;
  double _lockedBalance = 0.0;
  double _totalInterest = 0.0;
  double _totalInterestBal = 0.0;
  bool _isLoadingWallet = true;
  bool _isLoadingHistory = true;
  bool _isLoading = false;
  List<Map<String, dynamic>> _lockHistory = [];

  @override
  void dispose() {
    _withdrawAmountController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchWalletAndLockedBalance();
    _fetchLockHistory();
  }

  Future<void> _fetchWalletAndLockedBalance() async {
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
            _lockedBalance =
                double.tryParse(data['locked_balance']?.toString() ?? '0') ??
                0.0;
            _totalInterestBal =
                double.tryParse(data['interest']?.toString() ?? '0') ?? 0.0;
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

  Future<void> _fetchLockHistory() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        setState(() => _isLoadingHistory = false);
        return;
      }

      final response = await http.get(
        Uri.parse(Constants.lockHistory),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Lock history response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            // Handle different response structures
            final historyData = data['result'] ?? [];

            if (historyData is List) {
              _lockHistory = historyData
                  .map(
                    (item) => {
                      'amount':
                          double.tryParse(item['amount']?.toString() ?? '0') ??
                          0.0,
                      'date':
                          item['date'] ??
                          item['unlock_date'] ??
                          item['created_at'] ??
                          '',
                      'interest':
                          double.tryParse(
                            item['interest']?.toString() ?? '0',
                          ) ??
                          0.0,
                      'status': item['status'] ?? 'active',
                    },
                  )
                  .toList();

              // Calculate total interest from history (for reference)
              _totalInterest = _lockHistory.fold(
                0.0,
                (sum, item) => sum + (item['interest'] as double),
              );
            }

            _isLoadingHistory = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching lock history: $e');
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  void _showWithdrawModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Withdraw Funds',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available: ₦${_formatBalance(_lockedBalance)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textColor.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),

                // Amount Input
                const Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.lightGrey, width: 2),
                  ),
                  child: TextField(
                    controller: _withdrawAmountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter amount to withdraw',
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
                ),
                const SizedBox(height: 24),

                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close modal
                      _proceedToWithdrawPin();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirm Withdrawal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _proceedToWithdrawPin() async {
    // Validation
    if (_withdrawAmountController.text.isEmpty) {
      _showSnackBar('Please enter an amount', Colors.red);
      return;
    }

    final amount =
        double.tryParse(_withdrawAmountController.text.replaceAll(',', '')) ??
        0.0;

    if (amount <= 0) {
      _showSnackBar('Please enter a valid amount', Colors.red);
      return;
    }

    if (amount > _lockedBalance) {
      _showSnackBar('Insufficient locked balance', Colors.red);
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

    // Navigate to PIN screen
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinEntryScreen(
          title: 'Confirm Withdrawal',
          subtitle: 'Enter your 4 digit PIN to withdraw funds',
          onPinComplete: (pin) => _processWithdrawal(pin),
          onForgotPin: () {
            Navigator.pop(context);
            _showSnackBar('Contact support to reset PIN', Colors.orange);
          },
        ),
      ),
    );
  }

  Future<void> _processWithdrawal(String pin) async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final amount =
          double.tryParse(_withdrawAmountController.text.replaceAll(',', '')) ??
          0.0;

      final payload = {'amount': amount, 'pin': pin};

      print('Withdrawal payload: $payload');

      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/payout/release'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);
      print('Withdrawal response: $responseData');

      if (!mounted) return;

      // Check if request was successful based on success field
      final bool isSuccess = responseData['success'] == true;
      final String message = responseData['message'] ?? '';

      if (response.statusCode == 401) {
        // Session expired
        Navigator.pop(context);
        _showSnackBar('Session expired. Please login again', Colors.red);
        await authService.logout();
        return;
      }

      if (isSuccess &&
          (response.statusCode == 200 || response.statusCode == 201)) {
        // Successful withdrawal
        Navigator.pop(context);

        // Clear input
        _withdrawAmountController.clear();

        // Refresh data
        _fetchWalletAndLockedBalance();
        _fetchLockHistory();

        // Show success message
        _showSuccessDialog(
          message.isNotEmpty ? message : 'Withdrawal successful',
          amount,
        );
      } else {
        // Failed withdrawal
        // Check if it's a PIN error
        if (message.toLowerCase().contains('pin') ||
            message.toLowerCase().contains('incorrect') ||
            message.toLowerCase().contains('invalid')) {
          // Keep PIN screen open for PIN errors
          _showSnackBar(
            message.isNotEmpty ? message : 'Invalid PIN',
            Colors.red,
          );
          throw Exception(message);
        } else {
          // Close PIN screen for other errors (like locked funds)
          Navigator.pop(context);
          _showSnackBar(
            message.isNotEmpty ? message : 'Failed to process withdrawal',
            Colors.red,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      // Only show snackbar if we haven't already shown one
      String errorMessage = e.toString().replaceAll('Exception: ', '');

      // Check if this is a PIN error we already displayed
      bool isPinError =
          errorMessage.toLowerCase().contains('pin') ||
          errorMessage.toLowerCase().contains('incorrect') ||
          errorMessage.toLowerCase().contains('invalid');

      if (!isPinError) {
        _showSnackBar(errorMessage, Colors.red);
      }
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
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 40,
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
              const SizedBox(height: 8),
              Text(
                '₦${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Credited to your wallet',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textColor.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[date.month - 1]} ${date.day} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
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
              height: 320,
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
                              'Save & Earn',
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
                    _isLoadingWallet
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Balance: ₦${_formatBalance(_walletNaira)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                    const SizedBox(height: 20),
                    // Lock Funds Button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LockFundScreen(),
                          ),
                        ).then((_) {
                          // Refresh when coming back
                          _fetchWalletAndLockedBalance();
                          _fetchLockHistory();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.lock_outline,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Lock Funds',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
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
            ),

            // Content Section with curved top
            Positioned(
              top: 160,
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
                      // Stats Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Amount Saved',
                              '₦${_formatBalance(_lockedBalance)}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Total Interest',
                              '₦${_formatBalance(_totalInterestBal)}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Info Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.lightGrey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Earn interest on your locked savings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textColor.withOpacity(0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Lock Histories Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'History',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          if (_lockHistory.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                // View all activities
                              },
                              child: Row(
                                children: [
                                  Text(
                                    'View all',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textColor.withOpacity(
                                        0.6,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: AppColors.textColor.withOpacity(0.6),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // History Items
                      if (_isLoadingHistory)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      else if (_lockHistory.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 48,
                                  color: AppColors.textColor.withOpacity(0.3),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No lock history yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textColor.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(
                          _lockHistory.length > 5 ? 5 : _lockHistory.length,
                          (index) {
                            final item = _lockHistory[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildActivityItem(
                                'Locked Funds',
                                _formatDate(item['date']),
                                '₦${_formatBalance(item['amount'])}',
                                item['status'],
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 40),

                      // Withdraw Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _lockedBalance > 0
                              ? _showWithdrawModal
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            disabledBackgroundColor: AppColors.lightGrey,
                          ),
                          child: const Text(
                            'Withdraw',
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

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String date,
    String amount,
    String status,
  ) {
    Color statusColor = Colors.green;
    if (status == 'pending') statusColor = Colors.orange;
    if (status == 'expired') statusColor = Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
