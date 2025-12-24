import 'package:cashpoint/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class TermOfUserScreen extends StatefulWidget {
  const TermOfUserScreen({super.key});

  @override
  State<TermOfUserScreen> createState() => _TermOfUserScreenState();
}

class _TermOfUserScreenState extends State<TermOfUserScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final userName = authService.userName;
        final userProfilePicture = authService.userProfilePicture;

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
                        // Profile Picture
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: userProfilePicture.isNotEmpty
                                ? Image.network(
                                    userProfilePicture,
                                    fit: BoxFit.cover,
                                    width: 60,
                                    height: 60,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: AppColors.primary,
                                        size: 30,
                                      );
                                    },
                                  )
                                : const Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                    size: 30,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Welcome, ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              TextSpan(
                                text: userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(
                                text: '!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content Section with curved top
                Positioned(
                  top: 190,
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(40, 30, 30, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Align(
                            alignment: Alignment.center,
                            child: Text(
                              'Term of Use',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'These Terms and Conditions constitute a legally binding agreement between you ("User") and VYCKZ EJ GLOBAL (RC: 3592966), operating under the brand name Eziplug ("Company").',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '1. Eligibility',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Users must be at least 18 years old to use Eziplug services.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '2. Account Registration',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Users must provide accurate information including name, phone number, email, and complete KYC verification using valid government-issued documents. You are responsible for maintaining the confidentiality of your account credentials.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '3. Prohibited Activities',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Users must not use Eziplug for unlawful purposes including fraud, money laundering, terrorist financing, or market manipulation. Violations may result in account suspension and reporting to authorities.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '4. Risk Disclosure',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Cryptocurrency transactions are volatile and irreversible. Eziplug is not liable for losses arising from user errors, incorrect wallet addresses, or market fluctuations.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '5. Wallet & Custody',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Eziplug may provide custodial and non-custodial wallet services. Users are solely responsible for safeguarding their private keys and passwords.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '6. Deposits & Withdrawals',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Eziplug supports internal transfers, blockchain transfers (USDT, USDC, BTC, etc.), and merchant transactions. Withdrawal limits are tied to KYC levels.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '7. Saving Products',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Eziplug offers Saving Products where Users can deposit funds to earn interest. Sub-products may include fixed-term deposits, flexible savings, or target savings. Interest rates vary based on deposit type, amount, and duration. Withdrawals may be subject to notice periods, penalties, or limits as published on our platform. Eziplug reserves the right to amend interest rates or terms in compliance with applicable laws.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '8. Intellectual Property',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'All Eziplug trademarks, software, and platform content remain the property of VYCKZ EJ GLOBAL.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '9. Limitation of Liability',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'The services are provided "as is." Eziplug is not responsible for indirect, incidental, or consequential damages, including downtime, loss of data, or third-party actions.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '10. Dispute Resolution',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'All disputes shall be resolved by arbitration in Lagos, Nigeria, in accordance with the Rules of Arbitration of the Chartered Institute of Arbitrators (UK).',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '11. Amendments and Termination',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Eziplug reserves the right to amend these Terms and the Privacy Policy. Users will be notified of material changes.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '12. Contact',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'For support, inquiries, or complaints, contact: support@eziplug.ng',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textColor,
      ),
    );
  }
}
