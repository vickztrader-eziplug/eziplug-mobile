import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/utils/constants.dart';

/// Unified Transaction Model matching backend Transaction structure
class UnifiedTransaction {
  final String id;
  final String reference;
  final String type; // 'credit' or 'debit'
  final String category; // 'airtime', 'data', 'giftcard', 'crypto', etc.
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String currency;
  final String status;
  final String description;
  final String? recipient;
  final String? provider;
  final DateTime createdAt;
  final Map<String, dynamic>? transactionable; // The polymorphic related data
  final Map<String, dynamic>? metadata; // Transaction metadata
  final Map<String, dynamic> rawData;

  UnifiedTransaction({
    required this.id,
    required this.reference,
    required this.type,
    required this.category,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.currency,
    required this.status,
    required this.description,
    this.recipient,
    this.provider,
    required this.createdAt,
    this.transactionable,
    this.metadata,
    required this.rawData,
  });

  /// Factory constructor to parse from API response
  factory UnifiedTransaction.fromJson(Map<String, dynamic> json) {
    return UnifiedTransaction(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      type: json['type']?.toString() ?? 'debit',
      category: json['category']?.toString() ?? 'other',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      balanceBefore: double.tryParse(json['balance_before']?.toString() ?? '0') ?? 0.0,
      balanceAfter: double.tryParse(json['balance_after']?.toString() ?? '0') ?? 0.0,
      currency: json['currency']?.toString() ?? 'NGN',
      status: json['status']?.toString() ?? 'pending',
      description: json['description']?.toString() ?? '',
      recipient: json['recipient']?.toString(),
      provider: json['provider']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      transactionable: _parseJsonMap(json['transactionable']),
      metadata: _parseJsonMap(json['metadata']),
      rawData: json,
    );
  }

  static Map<String, dynamic>? _parseJsonMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        return null;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Get display-friendly category label
  String get categoryLabel {
    switch (category) {
      case 'airtime':
        return 'Airtime';
      case 'data':
        return 'Data';
      case 'cable':
        return 'Cable';
      case 'bill':
        return 'Bill';
      case 'giftcard':
        return 'Giftcard';
      case 'crypto':
        return 'Crypto';
      case 'wallet_funding':
        return 'Payment';
      case 'wallet_transfer':
        return 'User Gift';
      case 'airtime_swap':
        return 'Airtime Swap';
      case 'betting':
        return 'Betting';
      case 'edupin':
        return 'Edupin';
      case 'payout':
        return 'Payout';
      case 'refund':
        return 'Refund';
      case 'bonus':
        return 'Bonus';
      default:
        return 'Other';
    }
  }

  /// Get display title based on category and type
  String get title {
    switch (category) {
      case 'airtime':
        return 'Airtime Purchase';
      case 'data':
        return 'Data Purchase';
      case 'cable':
        return 'Cable Purchase';
      case 'bill':
        return 'Bill Payment';
      case 'giftcard':
        return type == 'credit' ? 'Giftcard Sale' : 'Giftcard Purchase';
      case 'crypto':
        return type == 'credit' ? 'Crypto Sale' : 'Crypto Purchase';
      case 'wallet_funding':
        return 'Wallet Funding';
      case 'wallet_transfer':
        return 'Gift User';
      case 'airtime_swap':
        return 'Airtime Swap';
      case 'betting':
        return 'Betting';
      case 'edupin':
        return 'Edupin';
      case 'payout':
        return 'Payout';
      case 'refund':
        return 'Refund';
      case 'bonus':
        return 'Bonus';
      default:
        return 'Transaction';
    }
  }

  /// Get details string for display
  String get details {
    // Use description from backend if available
    if (description.isNotEmpty && description != 'null') {
      return description;
    }
    
    // Fallback: generate from transactionable data
    if (transactionable != null) {
      switch (category) {
        case 'airtime':
        case 'data':
          final network = transactionable!['network']?['name'] ?? '';
          final phone = transactionable!['phone'] ?? transactionable!['phone_number'] ?? '';
          return '$network - $phone';
        case 'giftcard':
          final cardType = transactionable!['card_type'] ?? 'Giftcard';
          return '$cardType - ₦${amount.toStringAsFixed(0)}';
        case 'crypto':
          final coinName = transactionable!['crypto']?['name'] ?? 'Crypto';
          return '$coinName - ₦${amount.toStringAsFixed(0)}';
        case 'cable':
          final cable = transactionable!['cable']?['name'] ?? 'Cable';
          final plan = transactionable!['cable_plan']?['name'] ?? '';
          return '$cable - $plan';
        case 'bill':
          final bill = transactionable!['bill']?['name'] ?? 'Bill';
          final account = transactionable!['account_number'] ?? transactionable!['meter_number'] ?? '';
          return '$bill - $account';
      }
    }
    
    return '₦${amount.toStringAsFixed(2)}';
  }
}

/// Unified Transaction Service - handles all transaction API calls
class TransactionService {
  /// Fetch all transactions with optional filters
  /// 
  /// [token] - Authentication token
  /// [category] - Filter by category (airtime, data, giftcard, crypto, etc.)
  /// [status] - Filter by status (pending, success, failed)
  /// [type] - Filter by type (credit, debit)
  /// [perPage] - Number of results per page
  /// [page] - Page number for pagination
  static Future<TransactionListResponse> fetchTransactions({
    required String token,
    String? category,
    String? status,
    String? type,
    int perPage = 50,
    int page = 1,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'per_page': perPage.toString(),
        'page': page.toString(),
      };
      
      if (category != null) queryParams['category'] = category;
      if (status != null) queryParams['status'] = status;
      if (type != null) queryParams['type'] = type;
      
      final uri = Uri.parse(Constants.transactions).replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Handle the transactions from response
        // Backend returns: { transactions: { data: [...], ... } }
        final transactionsData = data['transactions']?['data'] ?? 
                                 data['transactions'] ?? 
                                 data['data']?['data'] ?? 
                                 data['data'] ?? 
                                 [];
        
        final transactions = (transactionsData as List)
            .map((item) => UnifiedTransaction.fromJson(item))
            .toList();
        
        // Get pagination info
        final paginationData = data['transactions'] ?? data['data'];
        final currentPage = paginationData?['current_page'] ?? 1;
        final lastPage = paginationData?['last_page'] ?? 1;
        final total = paginationData?['total'] ?? transactions.length;
        
        return TransactionListResponse(
          success: true,
          transactions: transactions,
          currentPage: currentPage,
          lastPage: lastPage,
          total: total,
        );
      } else {
        print('Error fetching transactions: ${response.statusCode}');
        print('Response: ${response.body}');
        return TransactionListResponse(
          success: false,
          transactions: [],
          error: 'Failed to fetch transactions',
        );
      }
    } catch (e) {
      print('Exception fetching transactions: $e');
      return TransactionListResponse(
        success: false,
        transactions: [],
        error: e.toString(),
      );
    }
  }

  /// Fetch a single transaction by reference
  static Future<UnifiedTransaction?> fetchTransactionDetails({
    required String token,
    required String reference,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${Constants.transactionDetails}/$reference'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transactionData = data['transaction'] ?? data['data'];
        
        if (transactionData != null) {
          return UnifiedTransaction.fromJson(transactionData);
        }
      }
      return null;
    } catch (e) {
      print('Exception fetching transaction details: $e');
      return null;
    }
  }

  /// Fetch transaction summary
  static Future<Map<String, dynamic>?> fetchTransactionSummary({
    required String token,
    String? period,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (period != null) queryParams['period'] = period;
      
      final uri = Uri.parse(Constants.transactionsSummary).replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['summary'] ?? data['data'];
      }
      return null;
    } catch (e) {
      print('Exception fetching transaction summary: $e');
      return null;
    }
  }

  /// Fetch available transaction categories
  static Future<Map<String, String>> fetchCategories({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(Constants.transactionsCategories),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final categories = data['categories'] ?? {};
        return Map<String, String>.from(categories);
      }
      return {};
    } catch (e) {
      print('Exception fetching categories: $e');
      return {};
    }
  }
}

/// Response wrapper for transaction list
class TransactionListResponse {
  final bool success;
  final List<UnifiedTransaction> transactions;
  final int currentPage;
  final int lastPage;
  final int total;
  final String? error;

  TransactionListResponse({
    required this.success,
    required this.transactions,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.error,
  });
}
