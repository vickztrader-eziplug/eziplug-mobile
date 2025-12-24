import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../routes.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Optionally refresh user data when screen loads
    _refreshUserData();
  }

  Future<void> _refreshUserData() async {
    setState(() => _isRefreshing = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.refreshUserData();
    setState(() => _isRefreshing = false);
  }

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
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final userName = authService.userName;
        final userProfilePicture = authService.userProfilePicture;
        final walletNaira = authService.walletNaira;
        final walletDollar = authService.walletDollar;

        return Scaffold(
          backgroundColor: AppColors.primary,
          body: SafeArea(
            child: Column(
              children: [
                // Header Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: userProfilePicture.isNotEmpty
                              ? Image.network(
                                  userProfilePicture,
                                  fit: BoxFit.cover,
                                  width: 50,
                                  height: 50,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.person,
                                      color: AppColors.primary,
                                    );
                                  },
                                )
                              : Image.asset(
                                  'assets/images/user.jpg',
                                  fit: BoxFit.cover,
                                  width: 50,
                                  height: 50,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.person,
                                      color: AppColors.primary,
                                    );
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Welcome, ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              TextSpan(
                                text: userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(
                                text: '!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Refresh button
                      IconButton(
                        onPressed: _isRefreshing ? null : _refreshUserData,
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ],
                  ),
                ),

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
                          // Account section
                          _sectionTitle("Account"),
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
                                  icon: Icons.person_outline,
                                  title: "Personal Information",
                                  subtitle:
                                      "See your account information and login details",
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.editProfile,
                                    );
                                  },
                                ),
                                profileItem(
                                  icon: Icons.credit_card_outlined,
                                  title: "Bank Card/Account",
                                  subtitle:
                                      "₦${walletNaira.toStringAsFixed(2)} / \$${walletDollar.toStringAsFixed(2)} Linked",
                                  onTap: () {},
                                ),
                                profileItem(
                                  icon: Icons.leaderboard_outlined,
                                  title: "Leaderboard",
                                  subtitle:
                                      "See your ranking on the Eziplug leaderboard",
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.leaderboard,
                                    );
                                  },
                                  showDivider: false,
                                ),
                              ],
                            ),
                          ),

                          // Security section
                          _sectionTitle("Security"),
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
                                  icon: Icons.lock_outline,
                                  title: "Change Password",
                                  subtitle:
                                      "Make changes to your account password",
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.changePassword,
                                    );
                                  },
                                ),
                                profileItem(
                                  icon: Icons.verified_user_outlined,
                                  title: "KYC",
                                  subtitle:
                                      "Please verify your identity to have access to more features",
                                  onTap: () {
                                    Navigator.pushNamed(context, AppRoutes.kyc);
                                  },
                                ),
                                profileItem(
                                  icon: Icons.pin_outlined,
                                  title: "PIN Management",
                                  subtitle:
                                      "Make changes to your transaction PIN",
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.changePinOtp,
                                    );
                                  },
                                  showDivider: false,
                                ),
                              ],
                            ),
                          ),

                          // Services section
                          _sectionTitle("Services"),
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
                                  icon: Icons.info_outline,
                                  title: "About Us",
                                  subtitle: "Learn more about Cashpoint",
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.about,
                                    );
                                  },
                                ),
                                profileItem(
                                  icon: Icons.support_agent_outlined,
                                  title: "Help and Support",
                                  subtitle:
                                      "Contact our support, we are available 24/7",
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.support,
                                    );
                                  },
                                ),
                                profileItem(
                                  icon: Icons.description_outlined,
                                  title: "Terms and Conditions",
                                  subtitle:
                                      "See our terms of use and conditions",
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.termOfUse,
                                    );
                                  },
                                ),
                                profileItem(
                                  icon: Icons.shield_outlined,
                                  title: "Privacy Policy",
                                  subtitle: "See our privacy policy",
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.privacyPolicy,
                                    );
                                  },
                                  showDivider: false,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Logout
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: profileItem(
                              icon: Icons.logout_outlined,
                              title: "Logout",
                              subtitle: "Sign out of your account",
                              onTap: () async {
                                // Show confirmation dialog
                                final shouldLogout = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Logout'),
                                    content: const Text(
                                      'Are you sure you want to logout?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Logout'),
                                      ),
                                    ],
                                  ),
                                );

                                if (shouldLogout == true) {
                                  await authService.logout();
                                  if (mounted) {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      AppRoutes.login,
                                    );
                                  }
                                }
                              },
                              showDivider: false,
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
      },
    );
  }
}
