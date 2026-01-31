import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../services/auth_service.dart';
import '../reusable/pin_entry_screen.dart';
import 'lock_fund.dart';

class SaveAndEarnScreen extends StatefulWidget {
  const SaveAndEarnScreen({super.key});

  @override
  State<SaveAndEarnScreen> createState() => _SaveAndEarnScreenState();
}

class _SaveAndEarnScreenState extends State<SaveAndEarnScreen> {
  // Green color for Save & Earn
  static const Color _primaryColor = Color(0xFF4CAF50);

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
        final responseData = jsonDecode(response.body);
        final userData = responseData['data'] ?? responseData;

        if (mounted) {
          setState(() {
            _walletNaira =
                double.tryParse(userData['wallet_naira']?.toString() ?? '0') ?? 0.0;
            _lockedBalance =
                double.tryParse(userData['locked_balance']?.toString() ?? '0') ??
                0.0;
            _totalInterestBal =
                double.tryParse(userData['interest']?.toString() ?? '0') ?? 0.0;
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Padding(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: _primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Withdraw Funds',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Available: ₦${_formatBalance(_lockedBalance)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Amount Input using ModernFormWidgets
                ModernFormWidgets.buildTextField(
                  controller: _withdrawAmountController,
                  hintText: 'Enter amount to withdraw',
                  label: 'Amount',
                  prefixIcon: Icons.monetization_on_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),

                // Confirm Button
                ModernFormWidgets.buildPrimaryButton(
                  label: 'Confirm Withdrawal',
                  onPressed: () {
                    Navigator.pop(context);
                    _proceedToWithdrawPin();
                  },
                  backgroundColor: _primaryColor,
                  icon: Icons.check_circle_outline,
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
                  color: _primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: _primaryColor,
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
              const SizedBox(height: 8),
              Text(
                '₦${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
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
              ModernFormWidgets.buildPrimaryButton(
                label: 'Done',
                onPressed: () => Navigator.pop(context),
                backgroundColor: _primaryColor,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateString;
    }
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
                title: 'Save & Earn',
                walletBalance: _walletNaira,
                isLoadingBalance: _isLoadingWallet,
                primaryColor: _primaryColor,
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lock Funds Action Card
                      ModernFormWidgets.buildFormCard(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LockFundScreen(),
                              ),
                            ).then((_) {
                              _fetchWalletAndLockedBalance();
                              _fetchLockHistory();
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.lock_outline,
                                  color: _primaryColor,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Lock Funds',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Lock your funds and earn interest',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textColor.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: _primaryColor.withOpacity(0.6),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats Cards Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernStatCard(
                              'Amount Saved',
                              '₦${_formatBalance(_lockedBalance)}',
                              Icons.savings_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModernStatCard(
                              'Total Interest',
                              '₦${_formatBalance(_totalInterestBal)}',
                              Icons.trending_up,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Info Card
                      ModernFormWidgets.buildInfoCard(
                        message: 'Lock your funds for a period of time to earn interest. The longer you lock, the more you earn!',
                        icon: Icons.lightbulb_outline,
                        color: _primaryColor,
                      ),
                      const SizedBox(height: 24),

                      // History Section
                      ModernFormWidgets.buildFormCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ModernFormWidgets.buildSectionLabel(
                                  'Lock History',
                                  icon: Icons.history,
                                  iconColor: _primaryColor,
                                ),
                                if (_lockHistory.isNotEmpty)
                                  TextButton(
                                    onPressed: () {
                                      // View all activities
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'View all',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 16,
                                          color: _primaryColor,
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
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(
                                    color: _primaryColor,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else if (_lockHistory.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: _primaryColor.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.history,
                                          size: 36,
                                          color: _primaryColor.withOpacity(0.5),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No lock history yet',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textColor.withOpacity(0.6),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Start locking funds to see your history',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textColor.withOpacity(0.4),
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
                                    padding: EdgeInsets.only(
                                      bottom: index < _lockHistory.length - 1 ? 12 : 0,
                                    ),
                                    child: _buildModernActivityItem(
                                      'Locked Funds',
                                      _formatDate(item['date']),
                                      '₦${_formatBalance(item['amount'])}',
                                      item['status'],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Withdraw Button
                      ModernFormWidgets.buildPrimaryButton(
                        label: 'Withdraw Savings',
                        onPressed: _lockedBalance > 0 ? _showWithdrawModal : null,
                        backgroundColor: _primaryColor,
                        icon: Icons.account_balance_wallet_outlined,
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
                  color: _primaryColor,
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernStatCard(String label, String value, IconData icon) {
    return ModernFormWidgets.buildFormCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _primaryColor, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
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

  Widget _buildModernActivityItem(
    String title,
    String date,
    String amount,
    String status,
  ) {
    Color statusColor = _primaryColor;
    IconData statusIcon = Icons.check_circle;
    if (status == 'pending') {
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
    }
    if (status == 'expired') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_outline,
              color: _primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
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
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 10, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textColor.withOpacity(0.5),
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
              color: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
