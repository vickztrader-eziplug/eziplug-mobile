import 'package:flutter/material.dart';
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
    _walletPageController = PageController(viewportFraction: 0.92);
    
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
      
      // Debug: print what AuthService has
      print('AuthService user: ${authService.user}');
      print('AuthService userName: ${authService.userFullName}');
      
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
      print('Error fetching user data: $e');
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

    return Scaffold(
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
                    
                    SizedBox(height: sh * 0.03),
                    
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
                    
                    SizedBox(height: sh * 0.015),
                    
                    // Quick Actions Grid
                    _buildQuickActionsGrid(sw, sh),
                    
                    SizedBox(height: sh * 0.03),
                    
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
    );
  }

  Widget _buildHeader(double sw, double sh) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gradientStart,
            AppColors.gradientMiddle,
            AppColors.gradientEnd.withOpacity(0.9),
          ],
        ),
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
                            clipBehavior: Clip.antiAlias,
                            child: _userProfilePicture.isNotEmpty
                                ? Image.network(
                                    _userProfilePicture,
                                    fit: BoxFit.cover,
                                    width: sw * 0.09,
                                    height: sw * 0.09,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.asset(
                                        'assets/images/user.jpg',
                                        fit: BoxFit.cover,
                                        width: sw * 0.09,
                                        height: sw * 0.09,
                                      );
                                    },
                                  )
                                : Image.asset(
                                    'assets/images/user.jpg',
                                    fit: BoxFit.cover,
                                    width: sw * 0.09,
                                    height: sw * 0.09,
                                    errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.person,
                                          size: sw * 0.05,
                                          color: AppColors.primary,
                                        );
                                      },
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
                                _userName.split(' ').first,
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
    // Use a minimum height but allow it to expand
    final cardHeight = sh * 0.20 < 150 ? 150.0 : sh * 0.20;
    
    return Column(
      children: [
        SizedBox(
          height: cardHeight,
          child: PageView(
            controller: _walletPageController,
            onPageChanged: (index) => setState(() => _currentWalletPage = index),
            children: [
              _buildEnhancedWalletCard(
                sw, sh,
                currency: '₦',
                currencyName: 'Nigerian Naira',
                balance: _walletNaira,
                gradientColors: [AppColors.primary, AppColors.primaryLight],
                icon: Icons.account_balance_wallet_rounded,
              ),
              _buildEnhancedWalletCard(
                sw, sh,
                currency: '\$',
                currencyName: 'US Dollar',
                balance: _walletDollar,
                gradientColors: [AppColors.accentTeal, Color(0xFF00E5D0)],
                icon: Icons.attach_money_rounded,
              ),
            ],
          ),
        ),
        SizedBox(height: sh * 0.015),
        // Wallet Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.symmetric(horizontal: sw * 0.01),
              width: _currentWalletPage == index ? sw * 0.06 : sw * 0.02,
              height: sw * 0.02,
              decoration: BoxDecoration(
                color: _currentWalletPage == index
                    ? AppColors.primary
                    : AppColors.primary.withOpacity(0.25),
                borderRadius: BorderRadius.circular(sw * 0.01),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEnhancedWalletCard(
    double sw,
    double sh, {
    required String currency,
    required String currencyName,
    required double balance,
    required List<Color> gradientColors,
    required IconData icon,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: sw * 0.01),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(sw * 0.06),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned(
            right: -sw * 0.1,
            top: -sw * 0.1,
            child: Container(
              width: sw * 0.5,
              height: sw * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            left: -sw * 0.15,
            bottom: -sw * 0.15,
            child: Container(
              width: sw * 0.4,
              height: sw * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: EdgeInsets.all(sw * 0.035),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(sw * 0.01),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(sw * 0.01),
                            ),
                            child: Icon(icon, color: Colors.white, size: sw * 0.03),
                          ),
                          SizedBox(width: sw * 0.008),
                          Flexible(
                            child: Text(
                              currencyName,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: sw * 0.022,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isRefreshing)
                      SizedBox(
                        width: sw * 0.025,
                        height: sw * 0.025,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                  ],
                ),
                
                // Balance section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Available Balance',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: sw * 0.022,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _isBalanceVisible
                                  ? '$currency ${_formatBalance(balance)}'
                                  : '$currency ••••••',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: sw * 0.055,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: sw * 0.01),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                          child: Container(
                            padding: EdgeInsets.all(sw * 0.015),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(sw * 0.012),
                            ),
                            child: Icon(
                              _isBalanceVisible
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: Colors.white,
                              size: sw * 0.03,
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FundScreen()),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.all(sw * 0.015),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(sw * 0.012),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: gradientColors[0],
                              size: sw * 0.03,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Action Buttons - at bottom
                Row(
                  children: [
                    _buildWalletActionButton(
                      sw,
                      'Bonus',
                      Icons.stars_rounded,
                      () {},
                    ),
                    SizedBox(width: sw * 0.01),
                    _buildWalletActionButton(
                      sw,
                      'Save & Earn',
                      Icons.savings_rounded,
                      () => Navigator.pushNamed(context, AppRoutes.saveAndEarn),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletActionButton(
    double sw,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: sw * 0.02, vertical: sw * 0.015),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(sw * 0.015),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: sw * 0.03),
            SizedBox(width: sw * 0.01),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: sw * 0.024,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
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
        'label': 'Gift Cards',
        'color': AppColors.giftcardColor,
        'bgColor': AppColors.giftcardColor.withOpacity(0.12),
        'destination': const SellGiftCardScreen(),
      },
      {
        'icon': Icons.currency_bitcoin_rounded,
        'label': 'Crypto',
        'color': AppColors.cryptoColor,
        'bgColor': AppColors.cryptoColor.withOpacity(0.12),
        'destination': const TradeCryptoScreen(),
      },
      {
        'icon': Icons.calculate_rounded,
        'label': 'Calculator',
        'color': AppColors.calculatorColor,
        'bgColor': AppColors.calculatorColor.withOpacity(0.12),
        'destination': const RateCalculatorScreen(),
      },
      {
        'icon': Icons.grid_view_rounded,
        'label': 'More',
        'color': AppColors.moreServicesColor,
        'bgColor': AppColors.moreServicesColor.withOpacity(0.12),
        'destination': const MoreServicesScreen(),
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: actions.map((action) {
        return Flexible(
          child: _buildQuickActionItem(
            sw,
            sh,
            icon: action['icon'] as IconData,
            label: action['label'] as String,
            color: action['color'] as Color,
            bgColor: action['bgColor'] as Color,
            destination: action['destination'] as Widget,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActionItem(
    double sw,
    double sh, {
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required Widget destination,
  }) {
    // Adaptive width with max constraint
    final itemWidth = sw * 0.18;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
      },
      child: Container(
        width: itemWidth,
        constraints: BoxConstraints(minWidth: 60, maxWidth: 80),
        padding: EdgeInsets.symmetric(vertical: sh * 0.015, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(sw * 0.035),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(sw * 0.025),
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
              child: Icon(icon, color: Colors.white, size: sw * 0.045),
            ),
            SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: sw * 0.026,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
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
                boxShadow: [
                  BoxShadow(
                    color: (advert['gradient'] as List<Color>)[0].withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
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
