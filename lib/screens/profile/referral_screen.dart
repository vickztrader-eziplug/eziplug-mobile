import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/pin_verification_modal.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  bool _isLoading = true;
  bool _isClaiming = false;
  String? _error;

  // Referral stats
  String _referralCode = '';
  int _totalReferrals = 0;
  int _activeReferrals = 0;
  double _totalEarned = 0;
  double _bonusBalance = 0;
  double _bonusPerReferral = 0;
  List<Map<String, dynamic>> _referralHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchReferralData();
  }

  Future<void> _fetchReferralData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _getToken();
      
      // Fetch stats and history in parallel
      final responses = await Future.wait([
        http.get(
          Uri.parse('${Constants.baseUrl}/referral/stats'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
        http.get(
          Uri.parse('${Constants.baseUrl}/referral/history'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ]);

      final statsResponse = responses[0];
      final historyResponse = responses[1];

      debugPrint('Stats API Status: ${statsResponse.statusCode}');
      debugPrint('Stats API Body: ${statsResponse.body}');

      if (statsResponse.statusCode == 200) {
        final data = json.decode(statsResponse.body);
        if (data['success'] == true) {
          final result = data['result'] ?? data['data'] ?? {};
          final stats = result['stats'] ?? result; // Stats may be nested or direct
          setState(() {
            _referralCode = stats['referral_code']?.toString() ?? '';
            _totalReferrals = int.tryParse(stats['total_referrals']?.toString() ?? '0') ?? 0;
            _activeReferrals = int.tryParse((stats['credited_referrals'] ?? stats['active_referrals'])?.toString() ?? '0') ?? 0;
            _totalEarned = double.tryParse(stats['total_earned']?.toString() ?? '0') ?? 0;
            _bonusBalance = double.tryParse(stats['bonus_balance']?.toString() ?? '0') ?? 0;
            _bonusPerReferral = double.tryParse(stats['referral_bonus_amount']?.toString() ?? stats['bonus_per_referral']?.toString() ?? '0') ?? 0;
          });
        }
      } else {
        debugPrint('Stats API failed with status: ${statsResponse.statusCode}');
      }

      debugPrint('History API Status: ${historyResponse.statusCode}');
      debugPrint('History API Body: ${historyResponse.body}');

      if (historyResponse.statusCode == 200) {
        final data = json.decode(historyResponse.body);
        if (data['success'] == true) {
          final result = data['result'] ?? data['data'];
          
          // Handle both formats: data could be the array directly or an object with 'referrals' key
          List<dynamic> referralsData = [];
          if (result is List) {
            referralsData = result;
          } else if (result is Map) {
            referralsData = result['referrals'] ?? [];
          }
          
          setState(() {
            _referralHistory = referralsData.map((r) {
              if (r is Map) {
                return Map<String, dynamic>.from(r);
              }
              return <String, dynamic>{};
            }).toList();
          });
        }
      }

      setState(() => _isLoading = false);
    } catch (e, stackTrace) {
      debugPrint('Referral fetch error: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _error = 'Failed to load referral data';
        _isLoading = false;
      });
    }
  }

  Future<void> _claimBonus() async {
    if (_bonusBalance <= 0) {
      ToastHelper.showError('No bonus balance to claim');
      return;
    }

    // Show PIN verification modal
    if (!mounted) return;
    
    final pin = await PinVerificationModal.show(
      context: context,
      title: 'Claim Bonus',
      subtitle: 'Enter your PIN to claim your referral bonus',
      amount: _formatCurrency(_bonusBalance),
      transactionType: 'Bonus Claim',
      recipient: 'Main Wallet',
      onForgotPin: () {
        ToastHelper.showError('Contact support to reset PIN');
      },
    );

    if (pin == null || pin.length != 4) {
      return;
    }

    setState(() => _isClaiming = true);

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${Constants.baseUrl}/referral/claim-bonus'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'pin': pin,
        }),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        final result = data['result'] ?? data['data'] ?? {};
        ToastHelper.showSuccess(data['message'] ?? 'Bonus claimed successfully!');
        setState(() {
          _bonusBalance = 0;
          _totalEarned = double.tryParse(result['total_earned']?.toString() ?? '0') ?? _totalEarned;
        });
        // Refresh data
        _fetchReferralData();
      } else {
        ToastHelper.showError(data['message'] ?? 'Failed to claim bonus');
      }
    } catch (e) {
      ToastHelper.showError('Failed to claim bonus');
    } finally {
      setState(() => _isClaiming = false);
    }
  }

  Future<String> _getToken() async {
    try {
      const storage = FlutterSecureStorage();
      return await storage.read(key: 'token') ?? '';
    } catch (e) {
      return '';
    }
  }

  void _copyReferralCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    ToastHelper.showSuccess('Referral code copied!');
  }

  void _shareReferralCode() {
    final shareText = 'Join Eziplug using my referral code: $_referralCode\n'
        'Download now and get rewards when you complete your first transaction!';
    Share.share(shareText);
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '₦${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₦${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₦${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: isDark ? theme.scaffoldBackgroundColor : AppColors.primary,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.light,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: isDark ? theme.scaffoldBackgroundColor : AppColors.primary,
          elevation: 0,
          title: const Text(
            'Referral & Bonus',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _fetchReferralData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Header with referral code
                        _buildReferralCodeCard(),
                        
                        // Bonus Balance Card
                        _buildBonusBalanceCard(),

                        // Stats Cards
                        _buildStatsSection(),

                        // Referral History
                        _buildHistorySection(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchReferralData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCodeCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark ? theme.scaffoldBackgroundColor : AppColors.primary,
            isDark ? theme.scaffoldBackgroundColor.withOpacity(0.8) : AppColors.primary.withOpacity(0.85),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        children: [
          const Text(
            'Your Referral Code',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _referralCode.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                  onPressed: _copyReferralCode,
                  tooltip: 'Copy code',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.copy_outlined,
                label: 'Copy',
                onTap: _copyReferralCode,
              ),
              const SizedBox(width: 20),
              _buildActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: _shareReferralCode,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Earn ${_formatCurrency(_bonusPerReferral)} for each friend who completes their first transaction',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonusBalanceCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Bonus Balance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _formatCurrency(_bonusBalance),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Available to claim to your main wallet',
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isClaiming || _bonusBalance <= 0 ? null : _claimBonus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isClaiming
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Claim Bonus Now',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Referral Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Total',
                  _totalReferrals.toString(),
                  Icons.people_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Active',
                  _activeReferrals.toString(),
                  Icons.how_to_reg_rounded,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Earned',
                  _formatCurrency(_totalEarned),
                  Icons.savings_rounded,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleMedium?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Referrals',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          if (_referralHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.group_add_rounded, size: 48, color: theme.disabledColor.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    'No history found',
                    style: TextStyle(color: theme.disabledColor),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _referralHistory.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildHistoryItem(_referralHistory[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> referral) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final name = referral['name'] ?? 'Unknown User';
    final username = referral['username'] ?? '';
    final status = referral['status']?.toString().toLowerCase() ?? 'pending';
    final bonusAmount = double.tryParse(referral['bonus_amount']?.toString() ?? '0') ?? 0;
    final joinedAt = referral['joined_at'] ?? '';

    final isCompleted = status == 'completed' || status == 'active';
    final statusColor = isCompleted ? AppColors.success : Colors.orange;
    final statusText = isCompleted ? 'Completed' : 'Pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
                if (username.isNotEmpty)
                  Text(
                    '@$username',
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isCompleted ? '+₦${_formatBalance(bonusAmount)}' : '---',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? AppColors.success : theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBalance(double balance) {
    return balance.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
