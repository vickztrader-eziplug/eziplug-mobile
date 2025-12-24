import 'package:cashpoint/core/theme/app_colors.dart';
import 'package:cashpoint/routes.dart';
import 'package:flutter/material.dart';

class FundScreen extends StatefulWidget {
  const FundScreen({super.key});

  @override
  State<FundScreen> createState() => _FundScreenState();
}

class _FundScreenState extends State<FundScreen> {
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget profileItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.black38,
          ),
        ),
        if (showDivider)
          Divider(
            color: AppColors.lightGrey.withOpacity(0.3),
            height: 0,
            thickness: 1,
            indent: 76,
            endIndent: 16,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'Wallet',
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

            // White Content Card with Curve
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Funding Wallet Methods Section
                      _sectionTitle("Funding"),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.lightGrey.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            profileItem(
                              icon: Icons.account_balance_outlined,
                              title: "Bank Transfer",
                              subtitle:
                                  "Fund your naira wallet via bank transfer",
                              onTap: () {},
                            ),
                            profileItem(
                              icon: Icons.credit_card_outlined,
                              title: "Card Deposit",
                              subtitle:
                                  "Fund your naira wallet using your card",
                              onTap: () {},
                            ),
                            profileItem(
                              icon: Icons.monetization_on_outlined,
                              title: "USD (Optional)",
                              subtitle:
                                  "Fund your USD wallet using your card or USD account",
                              onTap: () {},
                              showDivider: false,
                            ),
                          ],
                        ),
                      ),

                      // Withdrawal Methods Section
                      _sectionTitle("Withdrawal"),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.lightGrey.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // profileItem(
                            //   icon: Icons.account_balance_wallet_outlined,
                            //   title: "Withdraw to wallet",
                            //   subtitle: "Withdrawal to your naira wallet",
                            //   onTap: () {},
                            // ),
                            profileItem(
                              icon: Icons.account_balance_outlined,
                              title: "Payout to bank",
                              subtitle: "Withdrawal to your bank account",
                              onTap: () {},
                            ),
                            // profileItem(
                            //   icon: Icons.swap_horiz_outlined,
                            //   title: "Wallet to Wallet Transfer",
                            //   subtitle: "Topup a friend wallet",
                            //   onTap: () {},
                            //   showDivider: false,
                            // ),
                          ],
                        ),
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
}
