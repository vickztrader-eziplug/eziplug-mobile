import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../services/auth_service.dart';
import 'lock_fund.dart';

class SaveAndEarnScreen extends StatefulWidget {
  const SaveAndEarnScreen({super.key});

  @override
  State<SaveAndEarnScreen> createState() => _SaveAndEarnScreenState();
}

class _SaveAndEarnScreenState extends State<SaveAndEarnScreen> {
  // Use unified app primary color
  static const Color _primaryColor = AppColors.primary;

  double _walletNaira = 0.0;
  double _lockedBalance = 0.0;
  double _totalInterest = 0.0;
  double _totalInterestBal = 0.0;
  bool _isLoadingWallet = true;
  bool _isLoadingHistory = true;
  List<Map<String, dynamic>> _lockHistory = [];

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

      print('User API response status: ${response.statusCode}');
      print('User API response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // API unwraps single-element arrays, so data is directly the user object
        final userData = responseData['data'] ?? responseData;
        
        print('Parsed userData: $userData');
        print('wallet_naira value: ${userData['wallet_naira']}');

        if (mounted) {
          setState(() {
            // Only set wallet balance here - locked balance comes from summary API
            _walletNaira =
                double.tryParse(userData['wallet_naira']?.toString() ?? '0') ?? 0.0;
            _isLoadingWallet = false;
          });
          print('Set _walletNaira to: $_walletNaira');
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

      // Fetch both history and summary in parallel
      final responses = await Future.wait([
        http.get(
          Uri.parse(Constants.lockHistory),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
        http.get(
          Uri.parse(Constants.lockSummary),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      ]);

      final historyResponse = responses[0];
      final summaryResponse = responses[1];

      print('Lock history response: ${historyResponse.body}');
      print('Lock summary response: ${summaryResponse.body}');

      if (mounted) {
        // Parse summary FIRST to get totals
        if (summaryResponse.statusCode == 200) {
          final summaryData = jsonDecode(summaryResponse.body);
          print('Summary data parsed: $summaryData');
          
          // API unwraps single-element arrays, so data is directly the summary object
          final summary = summaryData['data'] ?? {};
          print('Summary object: $summary');

          if (summary is Map) {
            final totalLocked = double.tryParse(summary['total_locked']?.toString() ?? '0') ?? 0.0;
            final totalInterestEarned = double.tryParse(summary['total_interest_earned']?.toString() ?? '0') ?? 0.0;
            
            print('Parsed total_locked: $totalLocked, total_interest_earned: $totalInterestEarned');
            
            _lockedBalance = totalLocked;
            _totalInterest = totalInterestEarned;
            _totalInterestBal = totalInterestEarned;
          }
        }

        // Parse history
        if (historyResponse.statusCode == 200) {
          final data = jsonDecode(historyResponse.body);
          print('History data parsed: $data');
          
          // API unwraps single-element arrays, so data is directly the history array
          final historyData = data['data'] ?? [];
          print('History array: $historyData');

          if (historyData is List) {
            _lockHistory = historyData
                .map(
                  (item) => {
                    'id': item['id'],
                    'reference': item['reference'] ?? '',
                    'amount':
                        double.tryParse(item['principal_amount']?.toString() ?? '0') ??
                        0.0,
                    'date': item['unlock_date'] ?? item['created_at'] ?? '',
                    'interest':
                        double.tryParse(
                          item['total_interest_earned']?.toString() ?? '0',
                        ) ??
                        0.0,
                    'expected_interest':
                        double.tryParse(
                          item['expected_interest']?.toString() ?? '0',
                        ) ??
                        0.0,
                    'interest_rate':
                        double.tryParse(
                          item['interest_rate']?.toString() ?? '0',
                        ) ??
                        0.0,
                    'status': item['status'] ?? 'active',
                    'remaining_days': item['remaining_days'] ?? 0,
                    'lock_days': item['lock_days'] ?? 0,
                  },
                )
                .toList()
                .cast<Map<String, dynamic>>();
            print('Parsed lock history count: ${_lockHistory.length}');
          }
        }

        setState(() {
          _isLoadingHistory = false;
        });
        
        print('Final state: _lockedBalance=$_lockedBalance, _totalInterestBal=$_totalInterestBal, _lockHistory.length=${_lockHistory.length}');
      }
    } catch (e) {
      print('Error fetching lock history: $e');
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: _primaryColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
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
                                      Navigator.pushNamed(context, '/lockFundHistory');
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
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
