import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../services/auth_service.dart';
import '../../routes.dart';
import '../transactions/airtime_screen.dart';
import '../transactions/data_screen.dart';
import '../transactions/fund_screen.dart';
import '../transactions/more_services.dart';
import '../transactions/rate_calculator.dart';
import '../transactions/sell_giftcard.dart';
import '../transactions/trade_crypto.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isBalanceVisible = false;
  late PageController _advertPageController;
  late Timer _advertTimer;
  int _currentAdvertPage = 0;

  // User data
  String _userName = 'User';
  String _userProfilePicture = '';
  double _walletNaira = 0.0;
  double _walletDollar = 0.0;
  bool _isLoadingUserData = true;
  bool _isRefreshing = false;

  // Sample advert data
  final List<Map<String, String>> _adverts = [
    {
      'title': 'Cable Purchase Easier',
      'description': 'GOTV, DSTV, and Startime integration with us made easier',
      'image': 'assets/images/cashpoint_onboard.png',
    },
    {
      'title': 'Trade Crypto Fast',
      'description':
          'Buy and sell crypto with instant settlement and best rates',
      'image': 'assets/images/cashpoint_onboard.png',
    },
    {
      'title': 'Gift Card Deals',
      'description':
          'Get amazing rates on iTunes, Amazon, and Steam gift cards',
      'image': 'assets/images/cashpoint_onboard.png',
    },
    {
      'title': 'Instant Airtime',
      'description': 'Buy airtime and data for all networks with zero delay',
      'image': 'assets/images/cashpoint_onboard.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _advertPageController = PageController(viewportFraction: 0.85);
    _startAutoScroll();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        setState(() => _isLoadingUserData = false);
        return;
      }

      final response = await http.get(
        Uri.parse(Constants.user),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userData = data;

        if (mounted) {
          setState(() {
            _userName = userData['firstName'] ?? 'User';
            _userProfilePicture =
                userData['profile'] ?? userData['avatar'] ?? '';
            _walletNaira =
                double.tryParse(userData['wallet_naira']?.toString() ?? '0') ??
                0.0;
            _walletDollar =
                double.tryParse(userData['wallet_usd']?.toString() ?? '0') ??
                0.0;
            _isLoadingUserData = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (mounted) {
        setState(() => _isLoadingUserData = false);
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);

    try {
      await _fetchUserData();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Balance updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error refreshing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh balance'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _startAutoScroll() {
    _advertTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentAdvertPage < _adverts.length - 1) {
        _currentAdvertPage++;
      } else {
        _currentAdvertPage = 0;
      }

      if (_advertPageController.hasClients) {
        _advertPageController.animateToPage(
          _currentAdvertPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _advertTimer.cancel();
    _advertPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppColors.primary,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          backgroundImage: _userProfilePicture.isNotEmpty
                              ? NetworkImage(_userProfilePicture)
                              : null,
                          child: _userProfilePicture.isEmpty
                              ? Text(
                                  _userName.isNotEmpty
                                      ? _userName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        RichText(
                          text: TextSpan(
                            text: 'Welcome, ',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                            children: [
                              TextSpan(
                                text: '${_userName.split(' ').first}!',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Refresh Button
                        IconButton(
                          onPressed: _isRefreshing ? null : _refreshData,
                          icon: _isRefreshing
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh_rounded,
                                  size: 26,
                                  color: AppColors.primary,
                                ),
                          tooltip: 'Refresh Balance',
                        ),
                        // Notification Button
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.notification,
                                );
                              },
                              icon: const Icon(
                                Icons.notifications_none_rounded,
                                size: 26,
                              ),
                            ),
                            Positioned(
                              right: 6,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Text(
                                  '3',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Balance Cards Horizontal Scroll
                _isLoadingUserData
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : SizedBox(
                        height: MediaQuery.of(context).size.height * 0.2,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _balanceCard(
                              context,
                              currency: '₦',
                              balance: _formatBalance(_walletNaira),
                            ),
                            const SizedBox(width: 15),
                            _balanceCard(
                              context,
                              currency: '\$',
                              balance: _formatBalance(_walletDollar),
                            ),
                          ],
                        ),
                      ),

                const SizedBox(height: 20),

                // Quick Refresh Hint (Optional)
                if (!_isLoadingUserData && !_isRefreshing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swipe_down_rounded,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Pull down to refresh',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),

                const Text(
                  'Quick Links',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 5),

                // Quick Links Grid - Original Design
                Column(
                  children: [
                    // First Row
                    Row(
                      children: [
                        Expanded(
                          child: _quickLinkCard(
                            context,
                            Icons.card_giftcard,
                            'Trade Giftcard',
                            'Enjoy sweet rates with swift payment',
                            const SellGiftCardScreen(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _quickLinkCard(
                            context,
                            Icons.currency_bitcoin,
                            'Trade Crypto',
                            'Trade BTC, ETH, BNB & More for instant cash',
                            const TradeCryptoScreen(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Second Row
                    Row(
                      children: [
                        Expanded(
                          child: _quickLinkCard(
                            context,
                            Icons.calculate_outlined,
                            'Use Rate Calculator',
                            'Use rate calculate to preview currency rate',
                            const RateCalculatorScreen(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _quickLinkCard(
                            context,
                            Icons.apps_rounded,
                            'More Service',
                            'Buy data, purchase airtime and utilities',
                            const MoreServicesScreen(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Dynamic Auto-Scrolling Adverts
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.15,
                  child: PageView.builder(
                    controller: _advertPageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentAdvertPage = index;
                      });
                    },
                    itemCount: _adverts.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _advertCard(
                          context,
                          _adverts[index]['title']!,
                          _adverts[index]['description']!,
                          _adverts[index]['image']!,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Indicator Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _adverts.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentAdvertPage == index ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentAdvertPage == index
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
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

  // Original Quick Link Card Widget
  Widget _quickLinkCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget destination,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Balance Card Widget with Toggle
  Widget _balanceCard(
    BuildContext context, {
    required String currency,
    required String balance,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Balance',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              // Refresh indicator on balance card
              if (_isRefreshing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _isBalanceVisible
                        ? '$currency $balance'
                        : '$currency ••••••',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Toggle visibility icon
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isBalanceVisible = !_isBalanceVisible;
                        });
                      },
                      child: Icon(
                        _isBalanceVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Fund wallet icon
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FundScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () {
                  // View bonus action
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white24,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'View Bonus',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.saveAndEarn);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save and Earn',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Dynamic Advert Card Widget
  Widget _advertCard(
    BuildContext context,
    String title,
    String description,
    String imagePath,
  ) {
    final double cardHeight = MediaQuery.of(context).size.height * 0.15;

    return Container(
      width: double.infinity,
      height: cardHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Image.asset(imagePath, height: cardHeight * 0.5, fit: BoxFit.contain),
        ],
      ),
    );
  }
}
