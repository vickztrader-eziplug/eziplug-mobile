import 'package:cashpoint/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
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
                              'Eziplug Privacy Policy',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'This Privacy Policy (the "Policy") represents the policy of VYCKZ EJ GLOBAL (RC: 3592966), a company incorporated under the laws of Nigeria (hereinafter referred to as "Eziplug", "Company", "we", "us", or "our"), regarding the collection, use, disclosure, and management of personal data.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '1. Introduction',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'This Policy applies to all visitors of our website, users of our mobile application, and clients who enroll in our services (collectively referred to as "Users"). By accessing or using Eziplug\'s services, you consent to the practices described in this Policy.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '2. Data We Collect',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Eziplug may collect personal identification information (name, date of birth, email, address, phone number), government-issued IDs (NIN, BVN, passport), financial information, device information, IP address, location data, transaction records, and communications data. Additional information such as savings preferences and transaction history may also be collected when Users use our Saving Products feature.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '3. Children\'s Data',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Eziplug does not knowingly collect information from persons under 18 years of age. If such data is discovered, it will be deleted immediately.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '4. How We Use Data',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'We use collected data to provide services, ensure security, verify identity (KYC/AML), process transactions, enhance user experience, conduct research, send communications, and comply with legal obligations. For Saving Products, data may also be used to calculate interest, track deposits, and enable withdrawals.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '5. Sharing of Data',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Eziplug does not sell user data. We may share information with regulators, legal authorities, and third-party service providers (such as payment processors and identity verification providers) strictly to enable service delivery or meet legal requirements.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '6. Data Security',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'We implement strong security measures including encryption, access controls, and monitoring to safeguard your data. However, no system is completely secure, and users are advised to keep their account credentials confidential.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '7. Your Rights',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Users have the right to access, correct, or delete personal information held by Eziplug, subject to legal and regulatory limitations.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 80),
                          const Text(
                            '8. Contact',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'For questions or concerns, please contact us at: support@eziplug.ng',
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
