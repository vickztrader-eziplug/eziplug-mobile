// import 'package:cashpoint/routes.dart';
// import 'package:cashpoint/screens/transactions/buy_giftcard.dart';
import 'package:cashpoint/routes.dart';
import 'package:cashpoint/screens/transactions/more_services.dart';
import 'package:cashpoint/screens/transactions/rate_calculator.dart';
import 'package:cashpoint/screens/transactions/sell_giftcard.dart';
import 'package:cashpoint/screens/transactions/trade_crypto.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  BuildContext? get context => null;

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
                          //Navigate to nofications route
                          Navigator.pop(context, AppRoutes.notification);
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

              // Balance Card
              // Balance Cards Horizontal Scroll
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.2,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _balanceCard(context),
                    const SizedBox(width: 15),
                    _balanceCard(context),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Quick Links',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 15),

              // Quick Links Grid
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                childAspectRatio: 1.4, // increase to make cards shorter
                children: [
                  _quickLink(
                    context,
                    Icons.card_giftcard,
                    'Trade Giftcard',
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
                    Icons.calculate_outlined,
                    'Rate Calculator',
                    'Use rate calculate to preview currency rate',
                    const RateCalculatorScreen(),
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

              const SizedBox(height: 10),
              SizedBox(
                height:
                    MediaQuery.of(context).size.height *
                    0.15, // parent container height
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _advertCard(context, 'assets/images/cashpoint_onboard.png'),
                    const SizedBox(width: 12),
                    _advertCard(context, 'assets/images/cashpoint_onboard.png'),
                    const SizedBox(width: 12),
                    _advertCard(context, 'assets/images/cashpoint_onboard.png'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Quick Link Helper Widget
  Widget _quickLink(
    BuildContext context, // Add context as parameter
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

  // Balance Card Widget
  Widget _balanceCard(BuildContext context) {
    final double cardHeight =
        MediaQuery.of(context).size.height * 0.35; // 35% of screen height

    return Container(
      width: MediaQuery.of(context).size.width * 0.75, // scrollable card width
      height: cardHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Available Balance',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '₦ ••••••',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.visibility_outlined, color: Colors.white, size: 26),
            ],
          ),
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
                onPressed: () {},
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

  // Advert Card Widget
  Widget _advertCard(BuildContext context, String imagePath) {
    final double cardHeight =
        MediaQuery.of(context).size.height * 0.18; // 18% of screen height

    return Container(
      width: MediaQuery.of(context).size.width * 0.75, // 75% of screen width
      height: cardHeight,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Text column
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Cable Purchase Easier',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'GOTV, DSTV, and Startime integration with us made easier',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Image.asset(
            imagePath,
            height: cardHeight * 0.5, // scale image relative to card height
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
