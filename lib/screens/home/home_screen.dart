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
  late PageController _walletPageController;
  late Timer _advertTimer;
  int _currentAdvertPage = 0;
  int _currentWalletPage = 0;

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
    _advertPageController = PageController(viewportFraction: 0.92);
    _walletPageController = PageController(viewportFraction: 1.0); // Full width
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

      if (mounted) {
        // Uncomment and use ScaffoldMessenger to show a snackbar if desired:
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Balance updated successfully'),
        //     backgroundColor: Colors.green,
        //     duration: Duration(seconds: 2),
        //     behavior: SnackBarBehavior.floating,
        //   ),
        // );

        // Fallback to logging when UI feedback is not used.
        print('Balance updated successfully');
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
    _walletPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppColors.primary,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                text: 'Welcome, ',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
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
                          ),
                        ],
                      ),
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
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: const Center(
                              child: Text(
                                '3',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Balance Cards - Full Width, Swipeable
                _isLoadingUserData
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 160,
                            child: PageView(
                              controller: _walletPageController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentWalletPage = index;
                                });
                              },
                              children: [
                                _balanceCard(
                                  context,
                                  currency: '₦',
                                  currencyLabel: 'Naira Balance',
                                  balance: _formatBalance(_walletNaira),
                                ),
                                _balanceCard(
                                  context,
                                  currency: '\$',
                                  currencyLabel: 'Dollar Balance',
                                  balance: _formatBalance(_walletDollar),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Wallet Indicator Dots
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              2,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentWalletPage == index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentWalletPage == index
                                      ? AppColors.primary
                                      : AppColors.primary.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                const SizedBox(height: 24),

                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 12),

                // Quick Actions Grid - 2 per row, larger cards
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    _quickActionCard(
                      context,
                      icon: Icons.card_giftcard_rounded,
                      title: 'Trade Giftcard',
                      subtitle: 'Best rates, instant pay',
                      color: const Color(0xFF6C5CE7),
                      destination: const SellGiftCardScreen(),
                    ),
                    _quickActionCard(
                      context,
                      icon: Icons.currency_bitcoin_rounded,
                      title: 'Trade Crypto',
                      subtitle: 'BTC, ETH & more',
                      color: const Color(0xFFF39C12),
                      destination: const TradeCryptoScreen(),
                    ),
                    _quickActionCard(
                      context,
                      icon: Icons.calculate_rounded,
                      title: 'Rate Calculator',
                      subtitle: 'Check live rates',
                      color: const Color(0xFF00B894),
                      destination: const RateCalculatorScreen(),
                    ),
                    _quickActionCard(
                      context,
                      icon: Icons.grid_view_rounded,
                      title: 'More Services',
                      subtitle: 'Bills, airtime & data',
                      color: const Color(0xFFE84393),
                      destination: const MoreServicesScreen(),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Dynamic Auto-Scrolling Adverts
                SizedBox(
                  height: 110,
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
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentAdvertPage == index ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentAdvertPage == index
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(3),
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

  /// New Quick Action Card - larger, more appealing
  Widget _quickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget destination,
  }) {
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickLinkCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget destination,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(screenWidth * 0.03),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: screenWidth * 0.06),
            ),
            SizedBox(height: screenHeight * 0.015),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.035,
                color: Colors.black,
              ),
            ),
            SizedBox(height: screenHeight * 0.005),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: screenWidth * 0.03,
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

  Widget _balanceCard(
    BuildContext context, {
    required String currency,
    required String currencyLabel,
    required String balance,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: currency == '₦' 
              ? [AppColors.primary, AppColors.primary.withOpacity(0.8)]
              : [const Color(0xFF2D3436), const Color(0xFF636E72)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (currency == '₦' ? AppColors.primary : Colors.grey).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currencyLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
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
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isBalanceVisible ? '$currency$balance' : '$currency••••••',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              _balanceActionButton(
                label: 'View Bonus',
                onTap: () {},
                filled: true,
              ),
              const SizedBox(width: 10),
              _balanceActionButton(
                label: 'Save & Earn',
                onTap: () => Navigator.pushNamed(context, AppRoutes.saveAndEarn),
                filled: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceActionButton({
    required String label,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: filled ? null : Border.all(color: Colors.white54, width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _advertCard(
    BuildContext context,
    String title,
    String description,
    String imagePath,
  ) {
    return Container(
      width: double.infinity,
      height: 100,
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
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Image.asset(imagePath, height: 50, fit: BoxFit.contain),
        ],
      ),
    );
  }
}
