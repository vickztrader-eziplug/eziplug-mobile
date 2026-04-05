import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../core/utils/constants.dart';
import '../../services/auth_service.dart';
import './transaction_details_screen.dart';
import './more_services.dart';

class TransactionModel {
  final String id;
  final String type;
  final String title;
  final String details;
  final DateTime date;
  final double amount;
  final String status;
  final String reference;
  final String provider;
  final Map<String, dynamic> rawData;

  TransactionModel({
    required this.id,
    required this.type,
    required this.title,
    required this.details,
    required this.date,
    required this.amount,
    required this.status,
    required this.reference,
    required this.provider,
    required this.rawData,
  });
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Airtime',
    'Airtime Swap',
    'Bill',
    'Cable',
    'Crypto',
    'Data',
    'Giftcard',
    'User Gift',
    'Payment',
  ];

  List<TransactionModel> _allTransactions = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchAllTransactions();
  }

  Future<void> _fetchAllTransactions() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();

      if (token == null || token.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch all histories in parallel for optimal performance
      final results = await Future.wait([
        _fetchGiftcardHistory(token),
        _fetchCryptoHistory(token),
        _fetchAirtimeHistory(token),
        _fetchAirtimeSwapHistory(token),
        _fetchBillHistory(token),
        _fetchCableHistory(token),
        _fetchDataHistory(token),
        _fetchPaymentHistory(token),
        _fetchGiftUserHistory(token), // ✅ Added
      ]);

      // Combine all transactions
      List<TransactionModel> combinedTransactions = [];
      for (var result in results) {
        combinedTransactions.addAll(result);
      }

      // Sort by date (most recent first)
      combinedTransactions.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _allTransactions = combinedTransactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching transactions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<List<TransactionModel>> _fetchGiftcardHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse(Constants.giftCardHistory),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transactions = data['data'] ?? data['results']?['data'] ?? [];

        return (transactions as List).map((item) {
          return TransactionModel(
            id: item['id']?.toString() ?? '',
            type: 'Giftcard',
            title: 'Giftcard Sale',
            details:
                '${item['card_type'] ?? 'Giftcard'} - ₦${item['amount'] ?? ''}',
            date: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
            amount: double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0,
            provider: item['card_type'],
            status: item['status'] ?? 'completed',
            reference: item['reference'] ?? item['transaction_id'] ?? 'N/A',
            rawData: item,
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching giftcard history: $e');
    }
    return [];
  }

  Future<List<TransactionModel>> _fetchCryptoHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse(Constants.cryptoHistory),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transactions = data['data'] ?? data['results']?['data'] ?? [];

        return (transactions as List).map((item) {
          String coinName = item['crypto']?['name']?.toString() ?? 'Crypto';
          String coinSymbol = item['crypto']?['symbol']?.toString() ?? '';

          return TransactionModel(
            id: item['id']?.toString() ?? '',
            type: 'Crypto',
            title: 'Crypto',
            details:
                '$coinName${coinSymbol.isNotEmpty ? " ($coinSymbol)" : ""} - ₦${item['amount'] ?? ''}',
            date: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
            amount: double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0,
            provider: item['crypto']['name'],
            status: item['status'] ?? 'completed',
            reference:
                item['transaction_hash'] ?? item['transaction_id'] ?? 'N/A',
            rawData: item,
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching crypto history: $e');
    }
    return [];
  }

  Future<List<TransactionModel>> _fetchAirtimeHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse(Constants.airtimeHistory),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transactions = data['data'] ?? data['results']?['data'] ?? [];
        print(transactions);
        return (transactions as List).map((item) {
          String networkName =
              item['network']?['name']?.toString() ??
              item['network']?.toString() ??
              'Airtime';

          return TransactionModel(
            id: item['id']?.toString() ?? '',
            type: 'Airtime',
            title: 'Airtime Sale',
            details: '$networkName - ${item['phone'] ?? ''}',
            date: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
            amount: double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0,
            provider: item['network']['name'],
            status: item['status'] ?? 'completed',
            reference: item['reference'] ?? item['transaction_id'] ?? 'N/A',
            rawData: item,
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching airtime history: $e');
    }
    return [];
  }

  Future<List<TransactionModel>> _fetchAirtimeSwapHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse(Constants.airtimeSwapHistory),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle nested structure: result -> data -> transactions
        final transactions =
            data['result']?['data']?['transactions'] ??
            data['data']?['transactions'] ??
            data['transactions'] ??
            [];

        return (transactions as List).map((item) {
          String networkName = item['network']?['name']?.toString() ?? '';

          return TransactionModel(
            id: item['id']?.toString() ?? '',
            type: 'Airtime Swap',
            title: 'Airtime Swap',
            details: '$networkName - ${item['phone_number'] ?? ''}',
            date: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
            amount:
                double.tryParse(item['cash_amount']?.toString() ?? '0') ?? 0.0,
            provider: networkName,
            status: item['status'] ?? 'pending',
            reference: item['transaction_id'] ?? 'N/A',
            rawData: item,
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching airtime swap history: $e');
    }
    return [];
  }

  Future<List<TransactionModel>> _fetchBillHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse(Constants.billHistory),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transactions = data['data'] ?? data['results']?['data'] ?? [];

        return (transactions as List).map((item) {
          String providerName =
              item['bill']?['name']?.toString() ??
              item['provider']?.toString() ??
              'Electric';

          return TransactionModel(
            id: item['id']?.toString() ?? '',
            type: 'Bill',
            title: 'Electricity Bill',
            details:
                '$providerName - ${item['account_number'] ?? item['meter_number'] ?? ''}',
            date: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
            amount: double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0,
            provider: item['bill']['name'],
            status: item['status'] ?? 'completed',
            reference: item['reference'] ?? item['transaction_id'] ?? 'N/A',
            rawData: item,
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching bill history: $e');
    }
    return [];
  }

  Future<List<TransactionModel>> _fetchCableHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse(Constants.cableHistory),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transactions = data['data'] ?? data['results']?['data'] ?? [];

        return (transactions as List).map((item) {
          String providerName =
              item['cable']?['name']?.toString() ??
              item['provider']?.toString() ??
              'Cable';

          return TransactionModel(
            id: item['id']?.toString() ?? '',
            type: 'Cable',
            title: 'Cable Purchase',
            details: '$providerName - ${item['cable_plan']['name'] ?? ''}',
            date: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
            amount: double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0,
            provider: item['cable']['name'],
            status: item['status'] ?? 'completed',
            reference: item['reference'] ?? item['transaction_id'] ?? 'N/A',
            rawData: item,
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching cable history: $e');
    }
    return [];
  }

  Future<List<TransactionModel>> _fetchDataHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse(Constants.dataHistory),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transactions = data['data'] ?? data['results']?['data'] ?? [];

        return (transactions as List).map((item) {
          String networkName =
              item['network']?['name']?.toString() ??
              item['network']?.toString() ??
              'Data';
          String planName =
              item['data_price']?['plan_name']?.toString() ??
              item['plan']?.toString() ??
              '';

          return TransactionModel(
            id: item['id']?.toString() ?? '',
            type: 'Data',
            title: 'Data Purchase',
            details: '$networkName - $planName',
            date: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
            amount: double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0,
            provider: item['network']['name'],
            status: item['status'] ?? 'completed',
            reference: item['reference'] ?? item['transaction_id'] ?? 'N/A',
            rawData: item,
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching data history: $e');
    }
    return [];
  }

  Future<List<TransactionModel>> _fetchPaymentHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse(Constants.paymentHistory),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle paginated response structure
        final transactions =
            data['payments']?['data'] ??
            data['data']?['data'] ??
            data['data'] ??
            [];

        return (transactions as List).map((item) {
          // Determine payment method/type
          String paymentType =
              item['type']?.toString().toUpperCase() ?? 'PAYMENT';
          String gateway = item['gateway']?.toString().toUpperCase() ?? '';

          // Create descriptive details
          String details =
              item['description']?.toString() ??
              'Payment via ${paymentType}${gateway.isNotEmpty ? " ($gateway)" : ""}';

          return TransactionModel(
            id: item['id']?.toString() ?? '',
            type: 'Payment',
            title: 'Wallet Funding',
            details: details,
            date: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
            amount: double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0,
            provider: gateway.isNotEmpty ? gateway : paymentType,
            status: item['status'] ?? 'pending',
            reference: item['reference'] ?? item['gateway_reference'] ?? 'N/A',
            rawData: item,
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching payment history: $e');
    }
    return [];
  }

  Future<List<TransactionModel>> _fetchGiftUserHistory(String token) async {
    try {
      final response = await http.get(
        Uri.parse(Constants.giftuserHistory),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle response structure
        final transactions = data['result'] ?? data['data'] ?? [];

        return (transactions as List).map((item) {
          // Extract recipient name from description if available
          String description =
              item['description']?.toString() ?? 'Gift Transfer';

          // Parse description to extract recipient
          // "Gifted 500 NGN to ashanke" -> extract "ashanke"
          String recipient = '';
          if (description.contains('to ')) {
            final parts = description.split('to ');
            if (parts.length > 1) {
              recipient = parts[1].trim();
            }
          }

          String details = recipient.isNotEmpty
              ? 'Gift to $recipient'
              : 'Gift Transfer';

          return TransactionModel(
            id: item['id']?.toString() ?? '',
            type: 'User Gift',
            title: 'Gift User',
            details: details,
            date: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
            amount: double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0,
            provider: item['channel']?.toString().toUpperCase() ?? 'WALLET',
            status: item['status'] ?? 'successful',
            reference: item['reference'] ?? 'N/A',
            rawData: item,
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching gift user history: $e');
    }
    return [];
  }

  List<TransactionModel> get _filteredTransactions {
    if (_selectedFilter == 'All') {
      return _allTransactions;
    }
    return _allTransactions
        .where((transaction) => transaction.type == _selectedFilter)
        .toList();
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Giftcard':
        return Icons.card_giftcard;
      case 'Crypto':
        return Icons.currency_bitcoin;
      case 'Airtime':
        return Icons.phone_android;
      case 'Airtime Swap':
        return Icons.swap_horiz;
      case 'Bill':
        return Icons.lightbulb_outline;
      case 'Cable':
        return Icons.tv;
      case 'Data':
        return Icons.wifi;
      case 'Payment':
        return Icons.payment;
      case 'User Gift':
        return Icons.card_giftcard;
      default:
        return Icons.receipt;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Giftcard':
        return Colors.purple;
      case 'Crypto':
        return Colors.orange;
      case 'Airtime':
        return Colors.blue;
      case 'Airtime Swap':
        return Colors.teal;
      case 'Bill':
        return Colors.yellow.shade700;
      case 'Cable':
        return Colors.indigo;
      case 'Data':
        return Colors.green;
      case 'Payment':
        return Colors.blueAccent;
      case 'User Gift':
        return Colors.pink;
      default:
        return AppColors.primary;
    }
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower == 'completed' ||
        statusLower == 'success' ||
        statusLower == 'successful') {
      return Colors.green;
    } else if (statusLower == 'pending' || statusLower == 'processing') {
      return Colors.orange;
    } else if (statusLower == 'failed' ||
        statusLower == 'cancelled' ||
        statusLower == 'rejected') {
      return Colors.red;
    }
    return Colors.grey;
  }

  String _formatDateTime(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // Convert to 12-hour format
    int hour = date.hour;
    String period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12; // Convert 0 to 12 for 12 AM

    String minute = date.minute.toString().padLeft(2, '0');

    return '${date.day} ${months[date.month - 1]}, ${date.year} • $hour:$minute $period';
  }

  void _navigateToDetail(TransactionModel transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(transaction: transaction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const MoreServicesScreen(),
                                ),
                              );
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
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedFilter,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: AppColors.primary,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white,
                          ),
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
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedFilter = newValue!;
                            });
                          },
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
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3) ?? AppColors.textColor.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load transactions',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6) ?? AppColors.textColor.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _fetchAllTransactions,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3) ?? AppColors.textColor.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions found',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6) ?? AppColors.textColor.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchAllTransactions,
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                          itemCount: _filteredTransactions.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final transaction = _filteredTransactions[index];
                            return _buildTransactionCard(transaction);
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
    final theme = Theme.of(context);
    final isPositive = transaction.type == 'Payment';
    final isGiftReceived =
        transaction.type == 'User Gift' &&
        transaction.details.contains('received'); // If you track received gifts

    final color = _getColorForType(transaction.type);
    final statusColor = _getStatusColor(transaction.status);

    return GestureDetector(
      onTap: () => _navigateToDetail(transaction),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
                  _getIconForType(transaction.type),
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
                              color: theme.textTheme.bodyLarge?.color ?? AppColors.textColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            transaction.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
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
                        color: theme.textTheme.bodySmall?.color ?? AppColors.textColor.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ref: ${transaction.reference}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.8) ?? AppColors.textColor.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDateTime(transaction.date),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7) ?? AppColors.textColor.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isPositive || isGiftReceived ? '+' : '-'} ₦${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: (isPositive || isGiftReceived)
                          ? Colors.green
                          : theme.textTheme.bodyLarge?.color ?? AppColors.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.5) ?? AppColors.textColor.withOpacity(0.3),
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
