import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/modern_form_widgets.dart';
import '../../services/auth_service.dart';
import 'buy_crypto.dart';
import 'sell_crypto.dart';

class TradeCryptoScreen extends StatefulWidget {
  const TradeCryptoScreen({super.key});

  @override
  State<TradeCryptoScreen> createState() => _TradeCryptoScreenState();
}

class _TradeCryptoScreenState extends State<TradeCryptoScreen> {
  double _walletNaira = 0.0;
  bool _isLoadingWallet = true;
  bool _isLoadingCoins = true;

  // Coins list from API
  List<Map<String, dynamic>> _coins = [];

  // Fallback icons & colors for known coins
  final Map<String, IconData> _coinIcons = {
    'BTC': Icons.currency_bitcoin_rounded,
    'USDT': Icons.attach_money_rounded,
    'ETH': Icons.diamond_rounded,
    'LTC': Icons.currency_exchange_rounded,
    'BNB': Icons.hexagon_rounded,
    'DOGE': Icons.pets_rounded,
    'TRX': Icons.swap_horiz_rounded,
    'XRP': Icons.water_drop_rounded,
    'SOL': Icons.wb_sunny_rounded,
    'ADA': Icons.eco_rounded,
  };

  final Map<String, List<Color>> _coinGradients = {
    'BTC': [const Color(0xFFF7931A), const Color(0xFFFFAE42)],
    'USDT': [const Color(0xFF26A17B), const Color(0xFF50D1A7)],
    'ETH': [const Color(0xFF627EEA), const Color(0xFF8FA4F5)],
    'LTC': [const Color(0xFF345D9D), const Color(0xFF6B8ECC)],
    'BNB': [const Color(0xFFF0B90B), const Color(0xFFF8D55C)],
    'DOGE': [const Color(0xFFC2A633), const Color(0xFFE0C85A)],
    'TRX': [const Color(0xFFFF060A), const Color(0xFFFF5A5D)],
    'XRP': [const Color(0xFF0085C0), const Color(0xFF40ADE0)],
    'SOL': [const Color(0xFF9945FF), const Color(0xFF14F195)],
    'ADA': [const Color(0xFF0033AD), const Color(0xFF3366CC)],
  };

  @override
  void initState() {
    super.initState();
    // Initialize with cached balance immediately so it doesn't show 0
    final authService = Provider.of<AuthService>(context, listen: false);
    _walletNaira = authService.walletNaira;
    if (_walletNaira > 0) {
      _isLoadingWallet = false;
    }
    _fetchWalletBalance();
    _fetchCoins();
  }

  Future<void> _fetchWalletBalance() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        setState(() => _isLoadingWallet = false);
        return;
      }

      final response = await http.get(
        Uri.parse(Constants.user),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final userData = responseData['data'] ?? responseData;

        if (mounted) {
          setState(() {
            _walletNaira =
                double.tryParse(userData['wallet_naira']?.toString() ?? '0') ?? 0.0;
            _isLoadingWallet = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  Future<void> _fetchCoins() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      final response = await http.get(
        Uri.parse(Constants.cryptoTypes),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final data = responseData['data'] ?? responseData['results'] ?? responseData;

        List<dynamic> coinsList = [];
        if (data is List) {
          coinsList = data;
        } else if (data is Map && data['data'] is List) {
          coinsList = data['data'];
        }

        if (mounted) {
          setState(() {
            _coins = coinsList.map<Map<String, dynamic>>((coin) => {
              'id': coin['id']?.toString() ?? '',
              'symbol': (coin['symbol'] ?? coin['name'] ?? '').toString().toUpperCase(),
              'name': coin['name'] ?? coin['symbol'] ?? '',
              'buy_rate_ngn': double.tryParse(coin['buy_rate_ngn']?.toString() ?? '0') ?? 0.0,
              'sell_rate_ngn': double.tryParse(coin['sell_rate_ngn']?.toString() ?? '0') ?? 0.0,
            }).toList();
            _isLoadingCoins = false;
          });
        }
      } else {
        _loadFallbackCoins();
      }
    } catch (e) {
      _loadFallbackCoins();
    }
  }

  void _loadFallbackCoins() {
    if (mounted) {
      setState(() {
        _coins = [
          {'id': '1', 'symbol': 'BTC', 'name': 'Bitcoin', 'buy_rate_ngn': 0.0, 'sell_rate_ngn': 0.0},
          {'id': '2', 'symbol': 'USDT', 'name': 'Tether', 'buy_rate_ngn': 0.0, 'sell_rate_ngn': 0.0},
          {'id': '3', 'symbol': 'ETH', 'name': 'Ethereum', 'buy_rate_ngn': 0.0, 'sell_rate_ngn': 0.0},
          {'id': '4', 'symbol': 'LTC', 'name': 'Litecoin', 'buy_rate_ngn': 0.0, 'sell_rate_ngn': 0.0},
        ];
        _isLoadingCoins = false;
      });
    }
  }

  void _showTradeOptionsModal(BuildContext context, Map<String, dynamic> coin) {
    final symbol = coin['symbol'] as String;
    final name = coin['name'] as String;
    final gradientColors = _coinGradients[symbol] ?? [AppColors.primary, AppColors.primaryLight];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Coin icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[0].withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _coinIcons[symbol] ?? Icons.currency_exchange_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Trade $symbol',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 24),

                // Buy Button
                ModernFormWidgets.buildPrimaryButton(
                  label: 'Buy $symbol',
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BuyCryptoScreen(
                          cryptoName: symbol,
                          cryptoId: coin['id']?.toString() ?? '',
                        ),
                      ),
                    );
                  },
                  backgroundColor: AppColors.success,
                  icon: Icons.arrow_downward_rounded,
                ),
                const SizedBox(height: 12),

                // Sell Button
                ModernFormWidgets.buildPrimaryButton(
                  label: 'Sell $symbol',
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SellCryptoScreen(
                          cryptoName: symbol,
                          cryptoId: coin['id']?.toString() ?? '',
                        ),
                      ),
                    );
                  },
                  backgroundColor: AppColors.accentPink,
                  icon: Icons.arrow_upward_rounded,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatBalance(double balance) {
    return balance
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Modern Gradient Header
          ModernFormWidgets.buildGradientHeader(
            context: context,
            title: 'Trade Crypto',
            subtitle: 'Buy & Sell cryptocurrency instantly',
            walletBalance: _walletNaira,
            isLoadingBalance: _isLoadingWallet,
            primaryColor: AppColors.primary,
          ),

          // Content Section
          Expanded(
            child: _isLoadingCoins
                ? _buildLoadingGrid()
                : _coins.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          await Future.wait([
                            _fetchWalletBalance(),
                            _fetchCoins(),
                          ]);
                        },
                        color: AppColors.primary,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section label
                              ModernFormWidgets.buildSectionLabel(
                                'Available Coins',
                                icon: Icons.currency_bitcoin_rounded,
                                iconColor: AppColors.cryptoColor,
                              ),
                              const SizedBox(height: 16),

                              // Coins Grid
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.35,
                                ),
                                itemCount: _coins.length,
                                itemBuilder: (context, index) {
                                  return _buildCoinCard(_coins[index]);
                                },
                              ),

                              const SizedBox(height: 20),

                              // Info card
                              ModernFormWidgets.buildInfoCard(
                                message: 'Tap a coin to buy or sell. Prices are updated in real-time. All transactions are processed on-chain.',
                                icon: Icons.info_outline_rounded,
                                color: AppColors.primary,
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinCard(Map<String, dynamic> coin) {
    final symbol = coin['symbol'] as String;
    final name = coin['name'] as String;
    final gradientColors = _coinGradients[symbol] ?? [AppColors.primary, AppColors.primaryLight];
    final icon = _coinIcons[symbol] ?? Icons.currency_exchange_rounded;

    return GestureDetector(
      onTap: () => _showTradeOptionsModal(context, coin),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top row: Icon + Symbol
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Gradient coin icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[0].withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                // Trade arrow indicator
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
              ],
            ),

            // Bottom section: Name + Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
        ),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withOpacity(0.3),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.cryptoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.currency_bitcoin_rounded,
                color: AppColors.cryptoColor,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No coins available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for available cryptocurrencies',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                setState(() => _isLoadingCoins = true);
                _fetchCoins();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
