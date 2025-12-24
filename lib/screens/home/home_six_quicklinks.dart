import 'package:cashpoint/routes.dart';
import 'package:cashpoint/screens/transactions/airtime_screen.dart';
import 'package:cashpoint/screens/transactions/data_screen.dart';
import 'package:cashpoint/screens/transactions/fund_screen.dart';
import 'package:cashpoint/screens/transactions/more_services.dart';
import 'package:cashpoint/screens/transactions/rate_calculator.dart';
import 'package:cashpoint/screens/transactions/sell_giftcard.dart';
import 'package:cashpoint/screens/transactions/trade_crypto.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/theme/app_colors.dart';

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
        child: SingleChildScrollView(
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
                      const CircleAvatar(
                        radius: 22,
                        backgroundImage: AssetImage(
                          'assets/images/cashpoint_onboard.png',
                        ),
                      ),
                      const SizedBox(width: 10),
                      RichText(
                        text: const TextSpan(
                          text: 'Welcome, ',
                          style: TextStyle(color: Colors.black, fontSize: 16),
                          children: [
                            TextSpan(
                              text: 'Alex!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamed(context, AppRoutes.notification);
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

              const SizedBox(height: 20),

              // Balance Cards Horizontal Scroll
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.2,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _balanceCard(context, currency: '₦', balance: '150,000.00'),
                    const SizedBox(width: 15),
                    _balanceCard(context, currency: '\$', balance: '250.50'),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                'Quick Links',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 25),

              // Quick Links Grid
              GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 15,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                childAspectRatio: 1.4,
                children: [
                  _quickLink(
                    context,
                    Icons.card_giftcard,
                    'Sell Giftcard',
                    'Enjoy sweet rates with swift payment',
                    const SellGiftCardScreen(),
                  ),
                  _quickLink(
                    context,
                    Icons.currency_bitcoin,
                    'Trade Crypto',
                    'Trade BTC, ETH, BNB & More for instant cash',
                    const TradeCryptoScreen(),
                  ),
                  _quickLink(
                    context,
                    Icons.phone_android_outlined,
                    'Buy Airtime',
                    'Buy airtime and data for all networks with zero delay',
                    const AirtimeScreen(),
                  ),
                  _quickLink(
                    context,
                    Icons.calculate_outlined,
                    'Rate Calculator',
                    'Use rate calculate to preview currency rate',
                    const RateCalculatorScreen(),
                  ),
                  _quickLink(
                    context,
                    Icons.wifi,
                    'Buy Data',
                    'Buy data for all networks with zero delay',
                    const DataScreen(),
                  ),
                  _quickLink(
                    context,
                    Icons.apps_rounded,
                    'More Service',
                    'Buy data, purchase airtime and utilities',
                    const MoreServicesScreen(),
                  ),
                ],
              ),

              const SizedBox(height: 40),

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
    );
  }

  // Quick Link Helper Widget
  Widget _quickLink(
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 15),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            // Text(
            //   subtitle,
            //   textAlign: TextAlign.center,
            //   maxLines: 2,
            //   overflow: TextOverflow.ellipsis,
            //   style: const TextStyle(
            //     fontSize: 6,
            //     color: Colors.black54,
            //     height: 1.2,
            //   ),
            // ),
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
          const Text(
            'Available Balance',
            style: TextStyle(color: Colors.white70, fontSize: 14),
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
                        // Navigate to fund wallet
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
                  // Navigate to save and earn
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
