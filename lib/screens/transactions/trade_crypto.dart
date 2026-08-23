import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
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

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredCoins {
    if (_searchQuery.isEmpty) return _coins;
    return _coins.where((coin) {
      final symbol = (coin['symbol'] as String).toLowerCase();
      final name = (coin['name'] as String).toLowerCase();
      return symbol.contains(_searchQuery) || name.contains(_searchQuery);
    }).toList();
  }

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
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              'logo': coin['logo']?.toString(),
              'buy_rate_ngn': double.tryParse(coin['buy_rate_ngn']?.toString() ?? '0') ?? 0.0,
              'sell_rate_ngn': double.tryParse(coin['sell_rate_ngn']?.toString() ?? '0') ?? 0.0,
              'networks': coin['networks'] is List ? coin['networks'] : [],
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
          {'id': '1', 'symbol': 'BTC', 'name': 'Bitcoin', 'logo': null, 'buy_rate_ngn': 0.0, 'sell_rate_ngn': 0.0, 'networks': []},
          {'id': '2', 'symbol': 'USDT', 'name': 'Tether', 'logo': null, 'buy_rate_ngn': 0.0, 'sell_rate_ngn': 0.0, 'networks': []},
          {'id': '3', 'symbol': 'ETH', 'name': 'Ethereum', 'logo': null, 'buy_rate_ngn': 0.0, 'sell_rate_ngn': 0.0, 'networks': []},
          {'id': '4', 'symbol': 'LTC', 'name': 'Litecoin', 'logo': null, 'buy_rate_ngn': 0.0, 'sell_rate_ngn': 0.0, 'networks': []},
        ];
        _isLoadingCoins = false;
      });
    }
  }

  /// Circular coin logo with a graceful fallback to the gradient+icon avatar
  /// when there's no logo or it fails to load.
  Widget _buildCoinLogo(Map<String, dynamic> coin, {double size = 44}) {
    final symbol = coin['symbol'] as String;
    final logoUrl = Constants.resolveLogoUrl(coin['logo'] as String?);
    final gradientColors = _coinGradients[symbol] ?? [AppColors.primary, AppColors.primaryLight];
    final icon = _coinIcons[symbol] ?? Icons.currency_exchange_rounded;

    Widget fallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size / 2),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        );

    if (logoUrl == null) {
      debugPrint('[CryptoLogo] No logo for $symbol (raw="${coin['logo']}")');
      return fallback();
    }

    return ClipOval(
      child: Image.network(
        logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return fallback();
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[CryptoLogo] Failed to load "$logoUrl": $error');
          return fallback();
        },
      ),
    );
  }

  void _showTradeOptionsModal(BuildContext context, Map<String, dynamic> coin) {
    final symbol = coin['symbol'] as String;
    final name = coin['name'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
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
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Coin logo
                _buildCoinLogo(coin, size: 56),
                const SizedBox(height: 16),

                Text(
                  '$symbol',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 24),

                // Buy Button
                ModernFormWidgets.buildPrimaryButton(
                  label: 'Receive $symbol',
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BuyCryptoScreen(
                          cryptoName: symbol,
                          cryptoId: coin['id']?.toString() ?? '',
                          coin: coin,
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
                  label: 'Convert $symbol',
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SellCryptoScreen(
                          cryptoName: symbol,
                          cryptoId: coin['id']?.toString() ?? '',
                          coin: coin,
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Modern Gradient Header
          ModernFormWidgets.buildGradientHeader(
            context: context,
            title: 'Crypto',
            subtitle: 'Convert your cryptocurrency instantly',
            walletBalance: _walletNaira,
            isLoadingBalance: _isLoadingWallet,
            primaryColor: AppColors.primary,
          ),

          // Content Section
          Expanded(
            child: _isLoadingCoins
                ? _buildLoadingList()
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
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            ModernFormWidgets.buildSectionLabel(
                              'Available Coins',
                              icon: Icons.currency_bitcoin_rounded,
                              iconColor: AppColors.cryptoColor,
                            ),
                            const SizedBox(height: 12),
                            ModernFormWidgets.buildTextField(
                              controller: _searchController,
                              hintText: 'Search by name or symbol',
                              prefixIcon: Icons.search_rounded,
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      onPressed: () => _searchController.clear(),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            if (_filteredCoins.isEmpty)
                              _buildNoSearchResults()
                            else ...[
                              for (final coin in _filteredCoins) ...[
                                _buildCoinRow(coin),
                                const SizedBox(height: 10),
                              ],
                              ModernFormWidgets.buildInfoCard(
                                message: 'Tap a coin to receive or convert. Prices are updated in real-time.',
                                icon: Icons.info_outline_rounded,
                                color: AppColors.primary,
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinRow(Map<String, dynamic> coin) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final symbol = coin['symbol'] as String;
    final name = coin['name'] as String;

    return GestureDetector(
      onTap: () => _showTradeOptionsModal(context, coin),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildCoinLogo(coin, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    symbol,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '1 $symbol',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _coinRateLabel(coin),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.swap_vert_rounded,
                color: AppColors.primary,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "≈ ₦X" using the buy rate (what it costs to receive 1 unit), falling
  /// back to the sell rate if buy isn't configured for this coin.
  String _coinRateLabel(Map<String, dynamic> coin) {
    final buyRate = (coin['buy_rate_ngn'] as double?) ?? 0.0;
    final sellRate = (coin['sell_rate_ngn'] as double?) ?? 0.0;
    final rate = buyRate > 0 ? buyRate : sellRate;
    if (rate <= 0) return 'Rate N/A';
    return '≈ ₦${_formatBalance(rate)}';
  }

  Widget _buildLoadingList() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Container(
          height: 66,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary.withOpacity(0.3),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoSearchResults() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: isDark ? Colors.white38 : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No coins match "${_searchController.text.trim()}"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
            Text(
              'No coins available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for available cryptocurrencies',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey.shade500,
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
