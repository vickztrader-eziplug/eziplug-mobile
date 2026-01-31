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
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
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
                ),

                const SizedBox(height: 20),

                // Balance Cards - Horizontal Scroll (Old Design Style)
                _isLoadingUserData
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : SizedBox(
                        height: MediaQuery.of(context).size.height * 0.2,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _balanceCard(
                              context,
                              currency: '₦',
                              currencyLabel: 'Available Balance',
                              balance: _formatBalance(_walletNaira),
                            ),
                            const SizedBox(width: 15),
                            _balanceCard(
                              context,
                              currency: '\$',
                              currencyLabel: 'Available Balance',
                              balance: _formatBalance(_walletDollar),
                            ),
                          ],
                        ),
                      ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Text(
                    'Quick Links',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Quick Links Grid - 2 per row like old design
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    childAspectRatio: 1.4,
                    children: [
                      _quickActionCard(
                        context,
                        icon: Icons.card_giftcard,
                        title: 'Trade Giftcard',
                        subtitle: 'Enjoy sweet rates with swift payment',
                        color: AppColors.primary,
                        destination: const SellGiftCardScreen(),
                      ),
                      _quickActionCard(
                        context,
                        icon: Icons.currency_bitcoin,
                        title: 'Trade Crypto',
                        subtitle: 'Trade BTC, ETH, BNB & More for instant cash',
                        color: AppColors.primary,
                        destination: const TradeCryptoScreen(),
                      ),
                      _quickActionCard(
                        context,
                        icon: Icons.calculate_outlined,
                        title: 'Rate Calculator',
                        subtitle: 'Use rate calculate to preview currency rate',
                        color: AppColors.primary,
                        destination: const RateCalculatorScreen(),
                      ),
                      _quickActionCard(
                        context,
                        icon: Icons.apps_rounded,
                        title: 'More Service',
                        subtitle: 'Buy data, purchase airtime and utilities',
                        color: AppColors.primary,
                        destination: const MoreServicesScreen(),
                      ),
                    ],
                  ),
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

  /// Quick Action Card - Old design style with consistent look
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular Icon Background
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                height: 1.2,
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
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      width: screenWidth * 0.75,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: currency == '₦' ? AppColors.primary : const Color(0xFF2D3436),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            currencyLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isBalanceVisible ? '$currency$balance' : '$currency••••••',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
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
                      color: Colors.white,
                      size: 26,
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
                        color: Colors.white24,
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
          const Spacer(),
          Row(
            children: [
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white24,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'View Bonus',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.saveAndEarn),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save and Earn',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
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
