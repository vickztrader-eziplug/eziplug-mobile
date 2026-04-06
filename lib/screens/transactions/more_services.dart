import 'package:cashpoint/routes.dart';
import 'package:cashpoint/screens/home/main_screen.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// More Services Screen - Enhanced Version
class MoreServicesScreen extends StatelessWidget {
  const MoreServicesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Gradient App Bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: isDark ? AppColors.headerDark : AppColors.primary,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                );
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.headerDark : AppColors.primary,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'All Services',
                          style: TextStyle(
                            color: isDark ? theme.textTheme.bodyLarge?.color : Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Explore our complete range of services',
                          style: TextStyle(
                            color: isDark ? theme.textTheme.bodyMedium?.color?.withOpacity(0.7) : Colors.white.withOpacity(0.85),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Services Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Gift Cards Section
                _buildSectionHeader('Gift Cards', Icons.card_giftcard_rounded, AppColors.giftcardColor, context),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedServiceCard(
                        context: context,
                        title: 'Buy Giftcard',
                        subtitle: 'Shop gift cards',
                        icon: Icons.card_giftcard_outlined,
                        color: AppColors.giftcardColor,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.buyGiftcard),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEnhancedServiceCard(
                        context: context,
                        title: 'Sell Giftcard',
                        subtitle: 'Convert to cash',
                        icon: Icons.sell_outlined,
                        color: const Color(0xFFE91E63),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.sellGiftcard),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Airtime & Data Section
                _buildSectionHeader('Airtime & Data', Icons.phone_android_rounded, AppColors.airtimeColor, context),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedServiceCard(
                        context: context,
                        title: 'Buy Airtime',
                        subtitle: 'Recharge instantly',
                        icon: Icons.phone_android,
                        color: AppColors.airtimeColor,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.buyAirtime),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEnhancedServiceCard(
                        context: context,
                        title: 'Buy Data',
                        subtitle: 'Stay connected',
                        icon: Icons.wifi_rounded,
                        color: AppColors.dataColor,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.buyData),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildEnhancedServiceCard(
                  context: context,
                  title: 'Airtime Swap',
                  subtitle: 'Convert airtime to cash',
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFF9C27B0),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.airtimeSwap),
                  isFullWidth: true,
                ),

                const SizedBox(height: 24),

                // Bills Payment Section
                _buildSectionHeader('Bills & Utilities', Icons.receipt_long_rounded, AppColors.billsColor, context),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedServiceCard(
                        context: context,
                        title: 'Electricity',
                        subtitle: 'Pay power bills',
                        icon: Icons.flash_on_rounded,
                        color: AppColors.billsColor,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.buyElectricity),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEnhancedServiceCard(
                        context: context,
                        title: 'Cable TV',
                        subtitle: 'DSTV, GOTV & more',
                        icon: Icons.tv_rounded,
                        color: AppColors.cableColor,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.buyCable),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Entertainment & Gaming Section
                _buildSectionHeader('Entertainment', Icons.sports_esports_rounded, const Color(0xFF00BCD4), context),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedServiceCard(
                        context: context,
                        title: 'Betting',
                        subtitle: 'Fund betting wallet',
                        icon: Icons.sports_esports_rounded,
                        color: const Color(0xFF00BCD4),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.bet),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEnhancedServiceCard(
                        context: context,
                        title: 'Gift User',
                        subtitle: 'Send gifts',
                        icon: Icons.redeem_rounded,
                        color: const Color(0xFFFF5722),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.giftUser),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Education & Finance Section
                _buildSectionHeader('Education & Finance', Icons.school_rounded, const Color(0xFF3F51B5), context),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedServiceCard(
                        context: context,
                        title: 'Education PIN',
                        subtitle: 'Exam scratch cards',
                        icon: Icons.school_rounded,
                        color: const Color(0xFF3F51B5),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.educationPin),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEnhancedServiceCard(
                        context: context,
                        title: 'Save & Earn',
                        subtitle: 'Grow your money',
                        icon: Icons.savings_rounded,
                        color: const Color(0xFF4CAF50),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.saveAndEarn),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Tools Section
                _buildSectionHeader('Tools', Icons.build_rounded, AppColors.calculatorColor, context),
                const SizedBox(height: 12),
                _buildEnhancedServiceCard(
                  context: context,
                  title: 'Rate Calculator',
                  subtitle: 'Check live exchange rates',
                  icon: Icons.calculate_rounded,
                  color: AppColors.calculatorColor,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.rateCalculator),
                  isFullWidth: true,
                ),

                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedServiceCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isFullWidth ? 14 : 10,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.black.withOpacity(0.2) 
                    : Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,
                      color.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade300,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
