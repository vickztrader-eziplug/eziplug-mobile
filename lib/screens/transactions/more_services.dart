import 'package:cashpoint/routes.dart';
import 'package:cashpoint/screens/home/home3.dart';
import 'package:cashpoint/screens/home/main_screen.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// More Services Screen
class MoreServicesScreen extends StatelessWidget {
  const MoreServicesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const MainScreen(),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  const Text(
                    'More Services',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // White Content Card
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildServiceCard(
                              'Buy Giftcard',
                              Icons.card_giftcard_outlined,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.buyGiftcard,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _buildServiceCard(
                              'Sell Giftcard',
                              Icons.card_giftcard,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.sellGiftcard,
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: _buildServiceCard(
                      //         'Sell Crypto',
                      //         Icons.calculate_outlined,
                      //         () {
                      //           Navigator.pushNamed(
                      //             context,
                      //             AppRoutes.sellCrypto,
                      //           );
                      //         },
                      //       ),
                      //     ),
                      //     const SizedBox(width: 5),
                      //   ],
                      // ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: _buildServiceCard(
                              'Betting',
                              Icons.sports_esports_outlined,
                              () {
                                Navigator.pushNamed(context, AppRoutes.bet);
                              },
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _buildServiceCard(
                              'Gift User',
                              Icons.card_giftcard,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.giftUser,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: _buildServiceCard(
                              'Buy Airtime',
                              Icons.phone_android,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.buyAirtime,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _buildServiceCard(
                              'Buy Data',
                              Icons.wifi,
                              () {
                                Navigator.pushNamed(context, AppRoutes.buyData);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: _buildServiceCard(
                              'Electricity Bill',
                              Icons.flash_on_outlined,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.buyElectricity,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _buildServiceCard('Cable TV', Icons.tv, () {
                              Navigator.pushNamed(context, AppRoutes.buyCable);
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: _buildServiceCard(
                              'Education PIN',
                              Icons.school_outlined,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.educationPin,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _buildServiceCard(
                              'Airtime Swap',
                              Icons.swap_horiz,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.airtimeSwap,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: _buildServiceCard(
                              'Save & Earn',
                              Icons.savings_outlined,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.saveAndEarn,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: _buildServiceCard(
                              'Rate Calculator',
                              Icons.percent,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.rateCalculator,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
