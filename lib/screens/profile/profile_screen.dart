import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../routes.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshUserData();
  }

  Future<void> _refreshUserData() async {
    setState(() => _isRefreshing = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.refreshUserData();
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final userFullName = authService.userFullName;
        final userEmail = authService.userEmail;
        final userProfilePicture = authService.userProfilePicture;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: RefreshIndicator(
            onRefresh: _refreshUserData,
            color: AppColors.primary,
            child: CustomScrollView(
              slivers: [
                // Custom App Bar with Profile Header
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(sw * 0.08),
                        bottomRight: Radius.circular(sw * 0.08),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(sw * 0.05, sh * 0.02, sw * 0.05, sh * 0.04),
                        child: Column(
                          children: [
                            // Top Row with Title and Refresh
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'My Profile',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                                      : const Icon(Icons.refresh_rounded, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Profile Avatar and Info
                            Row(
                              children: [
                                // Avatar with border
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: CircleAvatar(
                                    radius: 35,
                                    backgroundColor: Colors.white,
                                    child: ClipOval(
                                      child: userProfilePicture.isNotEmpty
                                          ? Image.network(
                                              userProfilePicture,
                                              fit: BoxFit.cover,
                                              width: 70,
                                              height: 70,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.person,
                                                  color: AppColors.primary,
                                                  size: 35,
                                                );
                                              },
                                            )
                                          : Icon(
                                              Icons.person,
                                              color: AppColors.primary,
                                              size: 35,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Name and Email
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userFullName.isNotEmpty ? userFullName : 'User',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        userEmail,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Edit Profile Button
                                GestureDetector(
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.edit_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(sw * 0.05),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // ── Appearance Section ──────────────────────────────
                        _buildSectionTitle('Appearance', theme),
                        const SizedBox(height: 12),
                        _buildAppearanceCard(theme, isDark),

                        const SizedBox(height: 24),

                        // Account Section
                        _buildSectionTitle('Account', theme),
                        const SizedBox(height: 12),
                        _buildMenuCard(theme, [
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.person_outline_rounded,
                            iconColor: AppColors.primary,
                            title: 'Personal Information',
                            subtitle: 'Manage your account details',
                            onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
                          ),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.account_balance_outlined,
                            iconColor: const Color(0xFF00BFA5),
                            title: 'Payout Accounts',
                            subtitle: 'Manage your withdrawal accounts',
                            onTap: () => Navigator.pushNamed(context, AppRoutes.payoutAccounts),
                          ),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.leaderboard_rounded,
                            iconColor: const Color(0xFFFF9800),
                            title: 'Leaderboard',
                            subtitle: 'See your ranking',
                            onTap: () => Navigator.pushNamed(context, AppRoutes.leaderboard),
                            showDivider: false,
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // Security Section
                        _buildSectionTitle('Security', theme),
                        const SizedBox(height: 12),
                        _buildMenuCard(theme, [
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.lock_outline_rounded,
                            iconColor: const Color(0xFF7C4DFF),
                            title: 'Change Password',
                            subtitle: 'Update your account password',
                            onTap: () => Navigator.pushNamed(context, AppRoutes.changePassword),
                          ),
                          _buildKycMenuItem(authService, theme),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.pin_outlined,
                            iconColor: const Color(0xFFE91E63),
                            title: 'PIN Management',
                            subtitle: 'Manage your transaction PIN',
                            onTap: () => Navigator.pushNamed(context, AppRoutes.changePin),
                            showDivider: false,
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // Support Section
                        _buildSectionTitle('Support', theme),
                        const SizedBox(height: 12),
                        _buildMenuCard(theme, [
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.help_outline_rounded,
                            iconColor: const Color(0xFF2196F3),
                            title: 'Help & Support',
                            subtitle: 'Get help from our team',
                            onTap: () => Navigator.pushNamed(context, AppRoutes.support),
                          ),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.info_outline_rounded,
                            iconColor: const Color(0xFF607D8B),
                            title: 'About Us',
                            subtitle: 'Learn more about Eziplug',
                            onTap: () => Navigator.pushNamed(context, AppRoutes.about),
                          ),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.description_outlined,
                            iconColor: const Color(0xFF795548),
                            title: 'Terms & Conditions',
                            subtitle: 'Read our terms of service',
                            onTap: () => Navigator.pushNamed(context, AppRoutes.termOfUse),
                          ),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.shield_outlined,
                            iconColor: const Color(0xFF009688),
                            title: 'Privacy Policy',
                            subtitle: 'How we protect your data',
                            onTap: () => Navigator.pushNamed(context, AppRoutes.privacyPolicy),
                            showDivider: false,
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // Logout Button
                        _buildLogoutButton(authService, theme),

                        const SizedBox(height: 30),

                        // App Version
                        Center(
                          child: Text(
                            'Version 1.0.0',
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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

  // ── Appearance Card ──────────────────────────────────────────────────────

  Widget _buildAppearanceCard(ThemeData theme, bool isDark) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    themeProvider.isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        themeProvider.isDarkMode
                            ? 'Switch to light theme'
                            : 'Switch to dark theme',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                // Toggle Switch
                Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (_) => themeProvider.toggleTheme(),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Section title ────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: theme.textTheme.titleMedium?.color,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildMenuCard(ThemeData theme, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: showDivider ? null : BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon Container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  // Title and Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: theme.dividerColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            color: theme.dividerColor,
            height: 1,
            indent: 74,
            endIndent: 16,
          ),
      ],
    );
  }

  Widget _buildKycMenuItem(AuthService authService, ThemeData theme) {
    final kycTier = authService.user?['current_kyc_tier'] ?? 1;
    final hasPending = authService.user?['has_pending_kyc'] ?? false;

    Color tierColor;
    String tierText;
    IconData tierIcon;

    if (hasPending) {
      tierColor = Colors.orange;
      tierText = 'Pending';
      tierIcon = Icons.hourglass_empty_rounded;
    } else {
      switch (kycTier) {
        case 1:
          tierColor = Colors.grey;
          tierText = 'Tier 1';
          tierIcon = Icons.verified_user_outlined;
          break;
        case 2:
          tierColor = const Color(0xFF2196F3);
          tierText = 'Tier 2';
          tierIcon = Icons.verified_user_rounded;
          break;
        case 3:
          tierColor = const Color(0xFF00C853);
          tierText = 'Tier 3';
          tierIcon = Icons.verified_rounded;
          break;
        default:
          tierColor = Colors.grey;
          tierText = 'Tier 1';
          tierIcon = Icons.verified_user_outlined;
      }
    }

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, AppRoutes.kyc),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tierColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(tierIcon, color: tierColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KYC Verification',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasPending
                              ? 'Verification in progress'
                              : kycTier >= 3
                                  ? 'Fully verified'
                                  : 'Upgrade to unlock more features',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tierColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: tierColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasPending)
                          Icon(Icons.hourglass_empty_rounded, size: 14, color: tierColor)
                        else
                          Icon(
                            kycTier >= 3 ? Icons.check_circle : Icons.arrow_upward_rounded,
                            size: 14,
                            color: tierColor,
                          ),
                        const SizedBox(width: 4),
                        Text(
                          tierText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tierColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: theme.dividerColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(
          color: theme.dividerColor,
          height: 1,
          indent: 74,
          endIndent: 16,
        ),
      ],
    );
  }

  Widget _buildLogoutButton(AuthService authService, ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Logout',
                    style: TextStyle(color: theme.textTheme.titleMedium?.color),
                  ),
                ],
              ),
              content: Text(
                'Are you sure you want to sign out of your account?',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: theme.textTheme.bodySmall?.color),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Logout'),
                ),
              ],
            ),
          );

          if (shouldLogout == true) {
            await authService.logout();
            if (mounted) {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 22),
              const SizedBox(width: 10),
              Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
