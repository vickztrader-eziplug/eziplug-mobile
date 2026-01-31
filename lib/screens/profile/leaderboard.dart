import 'package:cashpoint/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<LeaderboardUser> _leaderboardData = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
        Uri.parse('https://cashpoint.deovaze.com/api/leaderboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          final List<dynamic> leaderboardList = data['result']['leaderboard'];
          
          setState(() {
            _leaderboardData = leaderboardList.map((item) {
              return LeaderboardUser(
                rank: item['rank'],
                name: item['user']['name'],
                avatar: item['user']['avatar'],
                totalVolume: item['total_volume'],
              );
            }).toList();
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

  String _formatVolume(String volume) {
    try {
      final double amount = double.parse(volume);
      if (amount >= 1000000) {
        return '₦${(amount / 1000000).toStringAsFixed(1)}M';
      } else if (amount >= 1000) {
        return '₦${(amount / 1000).toStringAsFixed(1)}K';
      }
      return '₦${amount.toStringAsFixed(0)}';
    } catch (e) {
      return '₦0';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              height: 220,
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
                    const SizedBox(height: 30),
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
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 60,
                                  color: Colors.red.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchLeaderboard,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchLeaderboard,
                            color: AppColors.primary,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                              child: Column(
                                children: [
                                  // Top 3 Podium
                                  if (_leaderboardData.length >= 3)
                                    _buildPodium(),
                                  const SizedBox(height: 30),
                                  // Full Leaderboard List
                                  if (_leaderboardData.isNotEmpty)
                                    _buildLeaderboardList(),
                                  if (_leaderboardData.isEmpty)
                                    _buildEmptyState(),
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium() {
    final top3 = _leaderboardData.take(3).toList();
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          // Second Place (Left)
          if (second != null)
            Positioned(
              left: 0,
              bottom: 30,
              child: _buildPodiumProfile(
                name: second.name,
                imageUrl: second.avatar,
                position: 2,
                volume: second.totalVolume,
              ),
            ),
          // First Place (Center)
          if (first != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: _buildPodiumProfile(
                name: first.name,
                imageUrl: first.avatar,
                position: 1,
                volume: first.totalVolume,
                isWinner: true,
              ),
            ),
          // Third Place (Right)
          if (third != null)
            Positioned(
              right: 0,
              bottom: 10,
              child: _buildPodiumProfile(
                name: third.name,
                imageUrl: third.avatar,
                position: 3,
                volume: third.totalVolume,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumProfile({
    required String name,
    String? imageUrl,
    required int position,
    required String volume,
    bool isWinner = false,
  }) {
    Color borderColor;
    Color badgeColor;

    switch (position) {
      case 1:
        borderColor = const Color(0xFFFDD835);
        badgeColor = const Color(0xFFFDD835);
        break;
      case 2:
        borderColor = const Color(0xFFB0BEC5);
        badgeColor = const Color(0xFFB0BEC5);
        break;
      case 3:
        borderColor = const Color(0xFFFFAB91);
        badgeColor = const Color(0xFFFFAB91);
        break;
      default:
        borderColor = Colors.grey;
        badgeColor = Colors.grey;
    }

    final String imageUrl_ = imageUrl != null && imageUrl.isNotEmpty
        ? 'https://cashpoint.deovaze.com/storage/$imageUrl'
        : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 3),
              ),
              child: CircleAvatar(
                radius: isWinner ? 40 : 32,
                backgroundImage:
                    imageUrl_.isNotEmpty ? NetworkImage(imageUrl_) : null,
                backgroundColor: AppColors.lightGrey.withOpacity(0.3),
                child: imageUrl_.isEmpty
                    ? Icon(
                        Icons.person,
                        size: isWinner ? 35 : 28,
                        color: Colors.grey,
                      )
                    : null,
              ),
            ),
            if (isWinner)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            if (!isWinner)
              Positioned(
                bottom: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '$position',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            fontSize: isWinner ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildLeaderboardList() {
    return Column(
      children: _leaderboardData.map((user) {
        return _buildLeaderboardItem(user);
      }).toList(),
    );
  }

  Widget _buildLeaderboardItem(LeaderboardUser user) {
    final String imageUrl = user.avatar != null && user.avatar!.isNotEmpty
        ? 'https://cashpoint.deovaze.com/storage/${user.avatar}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // Rank Badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: user.rank <= 3
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.lightGrey.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#${user.rank}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: user.rank <= 3 ? AppColors.primary : AppColors.textColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            backgroundColor: AppColors.lightGrey.withOpacity(0.3),
            child: imageUrl.isEmpty
                ? const Icon(Icons.person, size: 22, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              user.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Volume
          Text(
            _formatVolume(user.totalVolume),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.star,
            color: Color(0xFFFDD835),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.leaderboard_outlined,
            size: 80,
            color: AppColors.textColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Leaderboard Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for rankings',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// Leaderboard User Model
class LeaderboardUser {
  final int rank;
  final String name;
  final String? avatar;
  final String totalVolume;

  LeaderboardUser({
    required this.rank,
    required this.name,
    this.avatar,
    required this.totalVolume,
  });
}