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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
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
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Colors.grey.shade600),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.85),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    color: Colors.amber.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Bonus Balance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _formatCurrency(_bonusBalance),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Available to claim',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _bonusBalance > 0 && !_isClaiming ? _claimBonus : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _isClaiming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Claim to Wallet',
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
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.people_outline,
              label: 'Total Referrals',
              value: _totalReferrals.toString(),
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.check_circle_outline,
              label: 'Active',
              value: _activeReferrals.toString(),
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Total Earned',
              value: _formatCurrency(_totalEarned),
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Referral History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _referralHistory.isEmpty
              ? _buildEmptyHistory()
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _referralHistory.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _buildHistoryItem(_referralHistory[index]);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No referrals yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your referral code with friends\nto start earning bonuses!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> referral) {
    final name = referral['name'] ?? 'Unknown';
    final username = referral['username'] ?? '';
    final status = referral['status'] ?? 'pending';
    final bonusAmount = double.tryParse(referral['bonus_amount']?.toString() ?? '0') ?? 0;
    final joinedAt = referral['joined_at'] ?? '';

    final isPending = status == 'pending';
    final statusColor = isPending ? Colors.orange : Colors.green;
    final statusText = isPending ? 'Pending' : 'Completed';
    final statusIcon = isPending ? Icons.hourglass_empty : Icons.check_circle;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (username.isNotEmpty)
                  Text(
                    '@$username',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                if (joinedAt.isNotEmpty)
                  Text(
                    'Joined: $joinedAt',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isPending) ...[
                const SizedBox(height: 4),
                Text(
                  '+${_formatCurrency(bonusAmount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
