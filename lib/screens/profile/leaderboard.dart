import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  List<LeaderboardUser> _leaderboardData = [];
  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = 'month';
  String _selectedType = 'all';
  
  // Rewards info
  Map<String, dynamic> _rewards = {};
  Map<String, dynamic> _periodInfo = {};
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic> _stats = {};

  late TabController _tabController;

  final List<Map<String, String>> _periodOptions = [
    {'value': 'week', 'label': 'This Week'},
    {'value': 'month', 'label': 'This Month'},
    {'value': 'year', 'label': 'This Year'},
    {'value': 'all', 'label': 'All Time'},
  ];

  final List<Map<String, dynamic>> _typeOptions = [
    {'value': 'all', 'label': 'All Trades', 'icon': Icons.swap_horiz},
    {'value': 'crypto', 'label': 'Crypto', 'icon': Icons.currency_bitcoin},
    {'value': 'giftcard', 'label': 'Gift Cards', 'icon': Icons.card_giftcard},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _fetchLeaderboard();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final types = ['all', 'crypto', 'giftcard'];
    setState(() {
      _selectedType = types[_tabController.index];
    });
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse(
            '${Constants.baseUrl}/leaderboard?period=$_selectedPeriod&type=$_selectedType'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final result = data['result'] ?? data['data'] ?? {};
          final List<dynamic> leaderboardList = result['leaderboard'] ?? [];

          setState(() {
            _leaderboardData = leaderboardList.map((item) {
              return LeaderboardUser(
                rank: item['rank'] ?? 0,
                name: item['user']?['name'] ?? 'Unknown',
                avatar: item['user']?['avatar'],
                totalVolume: double.tryParse(item['total_volume']?.toString() ?? '0') ?? 0,
                isCurrentUser: item['user']?['is_current_user'] ?? false,
              );
            }).toList();
            
            _rewards = Map<String, dynamic>.from(result['rewards'] ?? {});
            _periodInfo = Map<String, dynamic>.from(result['period'] ?? {});
            _currentUser = result['current_user'] != null 
                ? Map<String, dynamic>.from(result['current_user']) 
                : null;
            _stats = Map<String, dynamic>.from(result['stats'] ?? {});
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data['message'] ?? 'Failed to load leaderboard';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Failed to load leaderboard';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: ${e.toString()}';
        _isLoading = false;
      });
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

  String _formatVolume(double volume) {
    if (volume >= 1000000) {
      return '₦${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '₦${(volume / 1000).toStringAsFixed(1)}K';
    }
    return '₦${volume.toStringAsFixed(0)}';
  }

  String _formatReward(dynamic amount) {
    if (amount == null) return '₦0';
    final value = double.tryParse(amount.toString()) ?? 0;
    if (value >= 1000) {
      return '₦${(value / 1000).toStringAsFixed(0)}K';
    }
    return '₦${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Gradient Header
          _buildHeader(),
          
          // Tab Bar for trade types
          _buildTabBar(),
          
          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : RefreshIndicator(
                        onRefresh: _fetchLeaderboard,
                        color: AppColors.primary,
                        child: _buildContent(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? AppColors.headerDark : AppColors.primary,
            isDark ? AppColors.headerDark : AppColors.primary.withOpacity(0.85),
            isDark ? AppColors.headerDark : AppColors.primaryLight,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Leaderboard',
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
            
            // Period Selector
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildPeriodSelector(),
            ),

            // Rewards Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: _buildRewardsBanner(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: _periodOptions.map((option) {
          final isSelected = _selectedPeriod == option['value'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedPeriod = option['value']!);
                _fetchLeaderboard();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    option['label']!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRewardsBanner() {
    final first = _formatReward(_rewards['first_place']);
    final second = _formatReward(_rewards['second_place']);
    final third = _formatReward(_rewards['third_place']);
    final daysRemaining = _periodInfo['days_remaining'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 20),
              const SizedBox(width: 8),
              Text(
                'Monthly Rewards',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRewardItem('🥈', '2nd', second),
              _buildRewardItem('🥇', '1st', first, isFirst: true),
              _buildRewardItem('🥉', '3rd', third),
            ],
          ),
          if (daysRemaining != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${daysRemaining is num ? daysRemaining.abs().toInt() : daysRemaining} days remaining',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRewardItem(String emoji, String place, String amount, {bool isFirst = false}) {
    return Column(
      children: [
        Text(
          emoji,
          style: TextStyle(fontSize: isFirst ? 32 : 24),
        ),
        const SizedBox(height: 4),
        Text(
          place,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: isFirst ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: theme.cardColor,
      child: TabBar(
        controller: _tabController,
        labelColor: isDark ? AppColors.primaryLight : AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: isDark ? AppColors.primaryLight : AppColors.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: _typeOptions.map((option) {
          return Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(option['icon'] as IconData, size: 16),
                const SizedBox(width: 6),
                Text(option['label'] as String),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // Current User Rank Card (if not in top 3)
          if (_currentUser != null && (_currentUser!['rank'] ?? 0) > 3)
            _buildCurrentUserCard(),
          
          // Top 3 Podium
          if (_leaderboardData.length >= 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _buildPodium(),
            ),
          
          // Stats Summary
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _buildStatsSummary(),
          ),
          
          // Full Leaderboard
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.format_list_numbered,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Full Rankings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_leaderboardData.length} traders',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_leaderboardData.isNotEmpty)
                  ..._leaderboardData.map((user) => _buildLeaderboardItem(user))
                else
                  _buildEmptyState(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentUserCard() {
    final rank = _currentUser!['rank'] ?? 0;
    final volume = double.tryParse(_currentUser!['total_volume']?.toString() ?? '0') ?? 0;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primaryLight.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Current Rank',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  _formatVolume(volume),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Keep Trading!',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    final top3 = _leaderboardData.take(3).toList();
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDD835).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Color(0xFFFDD835),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Top Traders',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Second Place (Left)
                if (second != null)
                  Expanded(
                    child: _buildPodiumItem(
                      user: second,
                      height: 100,
                      medalColor: const Color(0xFFB0BEC5),
                      medalEmoji: '🥈',
                    ),
                  ),
                // First Place (Center)
                if (first != null)
                  Expanded(
                    child: _buildPodiumItem(
                      user: first,
                      height: 130,
                      medalColor: const Color(0xFFFDD835),
                      medalEmoji: '🥇',
                      isFirst: true,
                    ),
                  ),
                // Third Place (Right)
                if (third != null)
                  Expanded(
                    child: _buildPodiumItem(
                      user: third,
                      height: 80,
                      medalColor: const Color(0xFFFFAB91),
                      medalEmoji: '🥉',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required LeaderboardUser user,
    required double height,
    required Color medalColor,
    required String medalEmoji,
    bool isFirst = false,
  }) {
    final String imageUrl = user.avatar != null && user.avatar!.isNotEmpty
        ? '${Constants.baseUrl.replaceAll('/api', '')}/storage/${user.avatar}'
        : '';

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // User Avatar with Medal
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: medalColor, width: 3),
                boxShadow: isFirst
                    ? [
                        BoxShadow(
                          color: medalColor.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: CircleAvatar(
                radius: isFirst ? 32 : 26,
                backgroundImage:
                    imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                backgroundColor: AppColors.lightGrey.withOpacity(0.3),
                child: imageUrl.isEmpty
                    ? Icon(
                        Icons.person,
                        size: isFirst ? 28 : 22,
                        color: Colors.grey,
                      )
                    : null,
              ),
            ),
            Positioned(
              bottom: -8,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  medalEmoji,
                  style: TextStyle(fontSize: isFirst ? 24 : 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // User Name
        Text(
          user.name,
          style: TextStyle(
            fontSize: isFirst ? 13 : 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        // Volume
        Text(
          _formatVolume(user.totalVolume),
          style: TextStyle(
            fontSize: isFirst ? 12 : 10,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        // Podium Base
        Container(
          width: double.infinity,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                medalColor.withOpacity(0.3),
                medalColor.withOpacity(0.5),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Center(
            child: Text(
              '#${user.rank}',
              style: TextStyle(
                fontSize: isFirst ? 20 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSummary() {
    final totalParticipants = _stats['total_participants'] ?? 0;
    final totalVolume = double.tryParse(_stats['total_volume']?.toString() ?? '0') ?? 0;
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.people_outline,
              label: 'Traders',
              value: totalParticipants.toString(),
              color: AppColors.info,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.lightGrey.withOpacity(0.3),
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.trending_up,
              label: 'Total Volume',
              value: _formatVolume(totalVolume),
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardItem(LeaderboardUser user) {
    final String imageUrl = user.avatar != null && user.avatar!.isNotEmpty
        ? '${Constants.baseUrl.replaceAll('/api', '')}/storage/${user.avatar}'
        : '';

    Color rankColor;
    IconData? rankIcon;
    
    switch (user.rank) {
      case 1:
        rankColor = const Color(0xFFFDD835);
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = const Color(0xFFB0BEC5);
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = const Color(0xFFFFAB91);
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = AppColors.lightGrey;
        rankIcon = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: user.isCurrentUser 
            ? AppColors.primary.withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: user.isCurrentUser 
            ? Border.all(color: AppColors.primary.withOpacity(0.3))
            : null,
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
          // Rank Badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: user.rank <= 3
                  ? rankColor.withOpacity(0.2)
                  : AppColors.lightGrey.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: rankIcon != null
                  ? Icon(rankIcon, color: rankColor, size: 18)
                  : Text(
                      '#${user.rank}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: user.rank <= 3 ? rankColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              backgroundColor: AppColors.lightGrey.withOpacity(0.3),
              child: imageUrl.isEmpty
                  ? const Icon(Icons.person, size: 20, color: Colors.grey)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: user.isCurrentUser ? AppColors.primary : AppColors.textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.isCurrentUser)
                  const Text(
                    'You',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Volume
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatVolume(user.totalVolume),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Loading leaderboard...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchLeaderboard,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.leaderboard_outlined,
                size: 48,
                color: AppColors.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Rankings Yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start trading to appear on the leaderboard!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Leaderboard User Model
class LeaderboardUser {
  final int rank;
  final String name;
  final String? avatar;
  final double totalVolume;
  final bool isCurrentUser;

  LeaderboardUser({
    required this.rank,
    required this.name,
    this.avatar,
    required this.totalVolume,
    this.isCurrentUser = false,
  });
}