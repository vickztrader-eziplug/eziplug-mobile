import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import './transaction_details_unified_screen.dart';
import '../home/main_screen.dart';

/// Optimized Transactions Screen using Unified Transactions API
/// 
/// Benefits:
/// - Single API call instead of 9 parallel calls
/// - Better performance and faster load times
/// - Consistent data structure from backend
/// - Built-in pagination support
/// - Server-side filtering capabilities
class TransactionsScreenUnified extends StatefulWidget {
  const TransactionsScreenUnified({super.key});

  @override
  State<TransactionsScreenUnified> createState() => _TransactionsScreenUnifiedState();
}

class _TransactionsScreenUnifiedState extends State<TransactionsScreenUnified> {
  String _selectedFilter = 'All';
  
  // Map display filter names to API category values
  final Map<String, String?> _filterMapping = {
    'All': null,
    'Airtime': 'airtime',
    'Airtime Swap': 'airtime_swap',
    'Bill': 'bill',
    'Cable': 'cable',
    'Crypto': 'crypto',
    'Data': 'data',
    'Giftcard': 'giftcard',
    'Payout': 'payout',
    'User Gift': 'wallet_transfer',
    'Payment': 'wallet_funding',
    'Betting': 'betting',
    'Edupin': 'edupin',
  };

  List<String> get _filterOptions => _filterMapping.keys.toList();

  List<UnifiedTransaction> _transactions = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  
  // Pagination
  int _currentPage = 1;
  int _lastPage = 1;
  bool _hasMorePages = false;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  /// Fetch transactions using the unified endpoint
  Future<void> _fetchTransactions({bool loadMore = false}) async {
    if (loadMore && _isLoadingMore) return;
    
    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _hasError = false;
        _currentPage = 1;
      }
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _hasError = true;
          _errorMessage = 'Not authenticated';
        });
        return;
      }

      // Get the category filter (null for 'All')
      final categoryFilter = _filterMapping[_selectedFilter];
      
      // Single API call!
      final response = await TransactionService.fetchTransactions(
        token: token,
        category: categoryFilter,
        perPage: 50,
        page: loadMore ? _currentPage + 1 : 1,
      );

      if (mounted) {
        if (response.success) {
          setState(() {
            if (loadMore) {
              _transactions.addAll(response.transactions);
              _currentPage = response.currentPage;
            } else {
              _transactions = response.transactions;
              _currentPage = response.currentPage;
            }
            _lastPage = response.lastPage;
            _hasMorePages = _currentPage < _lastPage;
            _isLoading = false;
            _isLoadingMore = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _isLoadingMore = false;
            _hasError = true;
            _errorMessage = response.error ?? 'Failed to load transactions';
          });
        }
      }
    } catch (e) {
      print('Error fetching transactions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// Called when filter changes - refetch with new filter
  void _onFilterChanged(String? newValue) {
    if (newValue != null && newValue != _selectedFilter) {
      setState(() {
        _selectedFilter = newValue;
      });
      _fetchTransactions(); // Refetch with new filter
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'giftcard':
        return Icons.card_giftcard;
      case 'crypto':
        return Icons.currency_bitcoin;
      case 'airtime':
        return Icons.phone_android;
      case 'airtime_swap':
        return Icons.swap_horiz;
      case 'bill':
        return Icons.lightbulb_outline;
      case 'cable':
        return Icons.tv;
      case 'data':
        return Icons.wifi;
      case 'wallet_funding':
        return Icons.payment;
      case 'wallet_transfer':
        return Icons.card_giftcard;
      case 'betting':
        return Icons.sports_soccer;
      case 'edupin':
        return Icons.school;
      case 'payout':
        return Icons.money;
      default:
        return Icons.receipt;
    }
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'giftcard':
        return Colors.purple;
      case 'crypto':
        return Colors.orange;
      case 'airtime':
        return Colors.blue;
      case 'airtime_swap':
        return Colors.teal;
      case 'bill':
        return Colors.yellow.shade700;
      case 'cable':
        return Colors.indigo;
      case 'data':
        return Colors.green;
      case 'wallet_funding':
        return Colors.blueAccent;
      case 'wallet_transfer':
        return Colors.pink;
      case 'betting':
        return Colors.red;
      case 'edupin':
        return Colors.brown;
      default:
        return AppColors.primary;
    }
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower == 'success' || statusLower == 'completed' || statusLower == 'successful') {
      return Colors.green;
    } else if (statusLower == 'pending' || statusLower == 'processing') {
      return Colors.orange;
    } else if (statusLower == 'failed' || statusLower == 'cancelled' || statusLower == 'rejected') {
      return Colors.red;
    } else if (statusLower == 'reversed') {
      return Colors.purple;
    }
    return Colors.grey;
  }

  String _formatDateTime(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    int hour = date.hour;
    String period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;

    String minute = date.minute.toString().padLeft(2, '0');

    return '${date.day} ${months[date.month - 1]}, ${date.year} • $hour:$minute $period';
  }

  void _navigateToDetail(UnifiedTransaction transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailUnifiedScreen(transaction: transaction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isDark ? AppColors.primaryDark : AppColors.primary,
                    isDark ? AppColors.primaryDark.withOpacity(0.8) : AppColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () {
                              // Navigate to main screen with bottom nav - this screen is part of MainScreen tabs
                              Navigator.of(context).pushReplacementNamed('/main');
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Transaction History',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedFilter,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: isDark ? const Color(0xFF1E2130) : AppColors.primary,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          items: _filterOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: _onFilterChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Section
            Positioned(
              top: 190,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _buildContent(theme, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: isDark ? AppColors.primaryLight : AppColors.primary),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to load transactions',
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchTransactions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchTransactions(),
      color: AppColors.primary,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Load more when near bottom
          if (notification is ScrollEndNotification &&
              notification.metrics.extentAfter < 200 &&
              _hasMorePages &&
              !_isLoadingMore) {
            _fetchTransactions(loadMore: true);
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
          itemCount: _transactions.length + (_hasMorePages ? 1 : 0),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == _transactions.length) {
              // Loading more indicator
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            return _buildTransactionCard(theme, isDark, _transactions[index]);
          },
        ),
      ),
    );
  }

  Widget _buildTransactionCard(ThemeData theme, bool isDark, UnifiedTransaction transaction) {
    final isCredit = transaction.type == 'credit';
    final color = _getColorForCategory(transaction.category);
    final statusColor = _getStatusColor(transaction.status);

    return GestureDetector(
      onTap: () => _navigateToDetail(transaction),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getIconForCategory(transaction.category),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.titleMedium?.color,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            transaction.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transaction.details,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatDateTime(transaction.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ref: ${transaction.reference}',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? '+' : '-'} ₦${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isCredit ? Colors.green : theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
