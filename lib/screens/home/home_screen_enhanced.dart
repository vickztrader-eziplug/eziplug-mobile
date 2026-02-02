import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
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

class HomeScreenEnhanced extends StatefulWidget {
  const HomeScreenEnhanced({super.key});

  @override
  State<HomeScreenEnhanced> createState() => _HomeScreenEnhancedState();
}

class _HomeScreenEnhancedState extends State<HomeScreenEnhanced>
    with TickerProviderStateMixin {
  bool _isBalanceVisible = false;
  late PageController _advertPageController;
  late PageController _walletPageController;
  late Timer _advertTimer;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  int _currentAdvertPage = 0;
  int _currentWalletPage = 0;

  // User data
  String _userName = 'User';
  String _userProfilePicture = '';
  double _walletNaira = 0.0;
  double _walletDollar = 0.0;
  bool _isLoadingUserData = true;
  bool _isRefreshing = false;

  // Time-based greeting
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // Advert data with gradients
  final List<Map<String, dynamic>> _adverts = [
    {
      'title': 'Trade Gift Cards',
      'description': 'Get the best rates for iTunes, Amazon & Steam cards',
      'icon': Icons.card_giftcard_rounded,
      'gradient': [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
    },
    {
      'title': 'Crypto Trading',
      'description': 'Buy & sell BTC, ETH, USDT with instant settlement',
      'icon': Icons.currency_bitcoin_rounded,
      'gradient': [Color(0xFFFFA726), Color(0xFFFFCC80)],
    },
    {
      'title': 'Bill Payments',
      'description': 'Pay electricity, cable TV & more seamlessly',
      'icon': Icons.receipt_long_rounded,
      'gradient': [Color(0xFF26C6DA), Color(0xFF80DEEA)],
    },
    {
      'title': 'Instant Airtime',
      'description': 'Top up any network in seconds, zero delays',
      'icon': Icons.phone_android_rounded,
      'gradient': [Color(0xFF66BB6A), Color(0xFFA5D6A7)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _advertPageController = PageController(viewportFraction: 0.88);
    _walletPageController = PageController(viewportFraction: 1.0);
    
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _startAutoScroll();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Use data from AuthService which was set during login
      if (mounted) {
        setState(() {
          _userName = authService.userFullName;
          _userProfilePicture = authService.userProfilePicture;
          _walletNaira = authService.walletNaira;
          _walletDollar = authService.walletDollar;
          _isLoadingUserData = false;
        });
      }
      
      // Also try to refresh from API
      final token = await authService.getToken();
      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse(Constants.user),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // Handle nested response: could be {data: {user: {...}}}, {data: {...}}, {user: {...}}, or flat {...}
        Map<String, dynamic> userData;
        if (responseData['data'] != null && responseData['data']['user'] != null) {
          userData = responseData['data']['user'];
        } else if (responseData['data'] != null) {
          userData = responseData['data'];
        } else if (responseData['user'] != null) {
          userData = responseData['user'];
        } else {
          userData = responseData;
        }
        
        if (mounted) {
          setState(() {
            final firstName = userData['first_name'] ?? userData['firstName'] ?? '';
            final lastName = userData['last_name'] ?? userData['lastName'] ?? '';
            _userName = lastName.isNotEmpty ? '$firstName $lastName' : (firstName.isNotEmpty ? firstName : _userName);
            _userProfilePicture = userData['profile'] ?? userData['avatar'] ?? userData['passport'] ?? _userProfilePicture;
            _walletNaira = double.tryParse(userData['wallet_naira']?.toString() ?? '') ?? _walletNaira;
            _walletDollar = double.tryParse(userData['wallet_usd']?.toString() ?? '') ?? _walletDollar;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    try {
      await _fetchUserData();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _startAutoScroll() {
    _advertTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentAdvertPage < _adverts.length - 1) {
        _currentAdvertPage++;
      } else {
        _currentAdvertPage = 0;
      }
      if (_advertPageController.hasClients) {
        _advertPageController.animateToPage(
          _currentAdvertPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _advertTimer.cancel();
    _advertPageController.dispose();
    _walletPageController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final sw = size.width;
    final sh = size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: AppColors.primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primary,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Gradient Header
            SliverToBoxAdapter(
              child: _buildHeader(sw, sh),
            ),
            
            // Main Content
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: sw * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: sh * 0.02),
                    
                    // Wallet Cards
                    _isLoadingUserData
                        ? _buildLoadingWallet(sw, sh)
                        : _buildWalletSection(sw, sh),
                    
                    const SizedBox(height: 20),
                    
                    // Quick Actions Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: sw * 0.045,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textColor,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MoreServicesScreen()),
                            );
                          },
                          child: Text(
                            'See All',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: sw * 0.035,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Quick Actions Grid
                    _buildQuickActionsGrid(sw, sh),
                    
                    const SizedBox(height: 20),
                    
                    // Promo Banner Section
                    Text(
                      'Latest Offers',
                      style: TextStyle(
                        fontSize: sw * 0.045,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textColor,
                      ),
                    ),
                    
                    SizedBox(height: sh * 0.015),
                    
                    // Auto-scrolling Promo Cards
                    _buildPromoSection(sw, sh),
                    
                    SizedBox(height: sh * 0.02),
                    
                    // Promo Indicators
                    _buildPromoIndicators(sw),
                    
                    SizedBox(height: sh * 0.03),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHeader(double sw, double sh) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(sw * 0.08),
          bottomRight: Radius.circular(sw * 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(sw * 0.05, sh * 0.02, sw * 0.05, sh * 0.04),
          child: Column(
            children: [
              // Top Row: Avatar & Notification
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // User Info - wrap in Expanded so inner Row gets constraints
                  Expanded(
                    child: Row(
                      children: [
                        // Animated Avatar Border
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.8 + _pulseController.value * 0.2),
                                    AppColors.accent.withOpacity(0.6 + _pulseController.value * 0.4),
                                  ],
                                ),
                              ),
                              child: child,
                            );
                          },
                          child: Container(
                            width: sw * 0.09,
                            height: sw * 0.09,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: Icon(
                              Icons.person,
                              size: sw * 0.055,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        SizedBox(width: sw * 0.03),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_greeting,',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: sw * 0.032,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Text(
                                _userName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: sw * 0.045,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Notification Button
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(sw * 0.03),
                        ),
                        child: IconButton(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.notification);
                          },
                          icon: Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: sw * 0.06,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          width: sw * 0.045,
                          height: sw * 0.045,
                          decoration: BoxDecoration(
                            color: AppColors.accentPink,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              '3',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: sw * 0.022,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWallet(double sw, double sh) {
    final cardHeight = sh * 0.20 < 150 ? 150.0 : sh * 0.20;
    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(sw * 0.05),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.3),
            AppColors.primaryLight.withOpacity(0.2),
          ],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildWalletSection(double sw, double sh) {
    // Use a fixed height that fits content well on all devices
    // Minimum 150, maximum 180 to prevent it from being too tall on large screens
    final cardHeight = (sh * 0.20).clamp(150.0, 180.0);
    
    return Column(
      children: [
        SizedBox(
          height: cardHeight,
          child: PageView(
            controller: _walletPageController,
            onPageChanged: (index) => setState(() => _currentWalletPage = index),
            children: [
              _buildBalanceCard(
                currency: '₦',
                currencyLabel: 'Naira',
                balance: _walletNaira,
                cardColor: AppColors.primary,
                cardHeight: cardHeight,
              ),
              _buildBalanceCard(
                currency: '\$',
                currencyLabel: 'Dollar',
                balance: _walletDollar,
                cardColor: AppColors.accentTeal,
                cardHeight: cardHeight,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Page Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentWalletPage == index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentWalletPage == index
                    ? AppColors.primary
                    : AppColors.primary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBalanceCard({
    required String currency,
    required String currencyLabel,
    required double balance,
    required Color cardColor,
    required double cardHeight,
  }) {
    // Define gradient colors based on card type
    final gradientColors = currency == '₦'
        ? [cardColor, cardColor.withOpacity(0.7), const Color(0xFF1A237E)]
        : [cardColor, cardColor.withOpacity(0.8), const Color(0xFF004D40)];

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles pattern
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Card content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute content evenly
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            currency == '₦' ? Icons.account_balance_wallet : Icons.currency_exchange,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$currencyLabel Balance',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // KYC Tier Badge
                    _buildKycBadge(),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _isBalanceVisible
                            ? '$currency ${_formatBalance(balance)}'
                            : '$currency ••••••',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                      child: Icon(
                        _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.white.withOpacity(0.7),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildCardButton(
                      label: 'Bonus',
                      icon: Icons.star_rounded,
                      bgColor: Colors.white.withOpacity(0.2),
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _buildCardButton(
                      label: 'Save & Earn',
                      icon: Icons.savings_rounded,
                      bgColor: Colors.white.withOpacity(0.2),
                      onTap: () => Navigator.pushNamed(context, AppRoutes.saveAndEarn),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FundScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: cardColor,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Fund',
                              style: TextStyle(
                                color: cardColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Card branding
          Positioned(
            bottom: 14,
            right: 18,
            child: Text(
              'EZIPLUG',
              style: TextStyle(
                color: Colors.white.withOpacity(0.15),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build KYC tier badge for balance card
  Widget _buildKycBadge() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final kycTier = authService.user?['current_kyc_tier'] ?? 1;
    final hasPending = authService.user?['has_pending_kyc'] ?? false;
    
    // Define badge properties based on tier and pending status
    IconData tierIcon;
    String tierText;
    Color bgColor;
    
    if (hasPending) {
      tierIcon = Icons.hourglass_top_rounded;
      tierText = 'Pending';
      bgColor = Colors.orange;
    } else {
      switch (kycTier) {
        case 3:
          tierIcon = Icons.workspace_premium_rounded;
          tierText = 'Tier 3';
          bgColor = AppColors.cryptoColor;
          break;
        case 2:
          tierIcon = Icons.verified_rounded;
          tierText = 'Tier 2';
          bgColor = AppColors.cryptoColor;
          break;
        default:
          tierIcon = Icons.person_outline_rounded;
          tierText = 'Tier 1';
          bgColor = AppColors.cryptoColor;
      }
    }
    
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.kyc),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tierIcon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              tierText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(double sw, double sh) {
    final actions = [
      {
        'icon': Icons.card_giftcard_rounded,
        'label': 'Trade Giftcard',
        'subtitle': 'Enjoy sweet rates with swift payment',
        'color': AppColors.giftcardColor,
        'bgColor': AppColors.giftcardColor.withOpacity(0.12),
        'destination': const SellGiftCardScreen(),
      },
      {
        'icon': Icons.currency_bitcoin_rounded,
        'label': 'Trade Crypto',
        'subtitle': 'Trade BTC, ETH, BNB & More for instant cash',
        'color': AppColors.cryptoColor,
        'bgColor': AppColors.cryptoColor.withOpacity(0.12),
        'destination': const TradeCryptoScreen(),
      },
      {
        'icon': Icons.calculate_rounded,
        'label': 'Rate Calculator',
        'subtitle': 'Use rate calculator to preview currency rate',
        'color': AppColors.calculatorColor,
        'bgColor': AppColors.calculatorColor.withOpacity(0.12),
        'destination': const RateCalculatorScreen(),
      },
      {
        'icon': Icons.grid_view_rounded,
        'label': 'More Services',
        'subtitle': 'Buy data, purchase airtime and utilities',
        'color': AppColors.moreServicesColor,
        'bgColor': AppColors.moreServicesColor.withOpacity(0.12),
        'destination': const MoreServicesScreen(),
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      childAspectRatio: 1.4,
      children: actions.map((action) {
        return _buildQuickActionItem(
          sw,
          sh,
          icon: action['icon'] as IconData,
          label: action['label'] as String,
          subtitle: action['subtitle'] as String,
          color: action['color'] as Color,
          bgColor: action['bgColor'] as Color,
          destination: action['destination'] as Widget,
        );
      }).toList(),
    );
  }

  Widget _buildQuickActionItem(
    double sw,
    double sh, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required Widget destination,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
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

  Widget _buildPromoSection(double sw, double sh) {
    // Adaptive height with minimum
    final promoHeight = sh * 0.12 < 90 ? 90.0 : sh * 0.12;
    
    return SizedBox(
      height: promoHeight,
      child: PageView.builder(
        controller: _advertPageController,
        onPageChanged: (index) => setState(() => _currentAdvertPage = index),
        itemCount: _adverts.length,
        itemBuilder: (context, index) {
          final advert = _adverts[index];
          return Padding(
            padding: EdgeInsets.only(right: sw * 0.03),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(sw * 0.04),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: advert['gradient'] as List<Color>,
                ),
              ),
              child: Stack(
                children: [
                  // Background decoration
                  Positioned(
                    right: -sw * 0.05,
                    bottom: -sw * 0.05,
                    child: Icon(
                      advert['icon'] as IconData,
                      size: sw * 0.2,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: EdgeInsets.all(sw * 0.03),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  advert['title'] as String,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: sw * 0.035,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(height: 4),
                              Flexible(
                                child: Text(
                                  advert['description'] as String,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: sw * 0.025,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(sw * 0.02),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(sw * 0.025),
                          ),
                          child: Icon(
                            advert['icon'] as IconData,
                            color: Colors.white,
                            size: sw * 0.06,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoIndicators(double sw) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_adverts.length, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(horizontal: sw * 0.008),
          width: _currentAdvertPage == index ? sw * 0.05 : sw * 0.02,
          height: sw * 0.02,
          decoration: BoxDecoration(
            color: _currentAdvertPage == index
                ? (_adverts[_currentAdvertPage]['gradient'] as List<Color>)[0]
                : AppColors.lightGrey.withOpacity(0.4),
            borderRadius: BorderRadius.circular(sw * 0.01),
          ),
        );
      }),
    );
  }

  String _formatBalance(double balance) {
    return balance.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
