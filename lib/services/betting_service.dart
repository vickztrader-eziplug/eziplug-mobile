import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/utils/constants.dart';
import '../core/utils/api_response.dart';
import '../models/bet_category.dart';
import '../models/bet_event.dart';
import '../models/bet_transaction.dart';
import 'auth_service.dart';

class BettingService {
  static const String baseUrl = Constants.baseUrl;

  /// Get all bet categories
  Future<Map<String, dynamic>> getCategories() async {
    final url = Uri.parse(Constants.bettingCategories);
    final authService = AuthService();
    final token = await authService.getToken();

    print('🔍 Calling: $url');
    print(
      '🔑 Token: ${token != null ? "${token.substring(0, 20)}..." : "null"}',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(result);
        print('✅ Decoded Result: $result');

        // Handle new format: { success, data: { categories } } or old format: { categories }
        List<dynamic>? categoriesList;
        if (apiResponse.data is Map && apiResponse.data['categories'] != null) {
          categoriesList = apiResponse.data['categories'] as List;
        } else if (result['categories'] != null) {
          categoriesList = result['categories'] as List;
        }

        if (categoriesList != null) {
          final categories = categoriesList
              .map((c) => BetCategory.fromJson(c))
              .toList();

          print('✅ Parsed ${categories.length} categories');

          return {'success': true, 'categories': categories};
        } else {
          print('❌ No categories key in response');
          return {
            'success': false,
            'message': apiResponse.message.isNotEmpty 
                ? apiResponse.message 
                : 'No categories found in response',
          };
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('❌ Error Body: ${response.body}');

        try {
          final errorResult = jsonDecode(response.body);
          return {
            'success': false,
            'message':
                errorResult['message'] ??
                'Failed to load categories (${response.statusCode})',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to load categories (${response.statusCode})',
          };
        }
      }
    } catch (e, stackTrace) {
      print('❌ Exception: $e');
      print('❌ Stack Trace: $stackTrace');
      return {'success': false, 'message': 'Server error: $e'};
    }
  }

  /// Get upcoming events
  Future<Map<String, dynamic>> getUpcomingEvents() async {
    final url = Uri.parse(Constants.bettingEvents);
    final authService = AuthService();
    final token = await authService.getToken();

    print('🔍 Calling: $url');
    print(
      '🔑 Token: ${token != null ? "${token.substring(0, 20)}..." : "null"}',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(result);
        print('✅ Decoded Result: $result');

        // Handle new format: { success, data: { events } } or old format: { events }
        List<dynamic>? eventsList;
        if (apiResponse.data is Map && apiResponse.data['events'] != null) {
          eventsList = apiResponse.data['events'] as List;
        } else if (result['events'] != null) {
          eventsList = result['events'] as List;
        }

        if (eventsList != null) {
          final events = eventsList
              .map((e) => BetEvent.fromJson(e))
              .toList();

          print('✅ Parsed ${events.length} events');

          return {'success': true, 'events': events};
        } else {
          print('❌ No events key in response');
          return {
            'success': false, 
            'message': apiResponse.message.isNotEmpty 
                ? apiResponse.message 
                : 'No events found in response',
          };
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('❌ Error Body: ${response.body}');

        try {
          final errorResult = jsonDecode(response.body);
          final apiError = ApiResponse.fromJson(errorResult);
          return {
            'success': false,
            'message': apiError.message.isNotEmpty
                ? apiError.message
                : 'Failed to load events (${response.statusCode})',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to load events (${response.statusCode})',
          };
        }
      }
    } catch (e, stackTrace) {
      print('❌ Exception: $e');
      print('❌ Stack Trace: $stackTrace');
      return {'success': false, 'message': 'Server error: $e'};
    }
  }

  /// Get events by category
  Future<Map<String, dynamic>> getEventsByCategory(int categoryId) async {
    final url = Uri.parse('$baseUrl/betting/events/category/$categoryId');
    final authService = AuthService();
    final token = await authService.getToken();

    print('🔍 Calling: $url');
    print(
      '🔑 Token: ${token != null ? "${token.substring(0, 20)}..." : "null"}',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(result);
        print('✅ Decoded Result: $result');

        // Handle new format: { success, data: { events } } or old format: { events }
        List<dynamic>? eventsList;
        if (apiResponse.data is Map && apiResponse.data['events'] != null) {
          eventsList = apiResponse.data['events'] as List;
        } else if (result['events'] != null) {
          eventsList = result['events'] as List;
        }

        if (eventsList != null) {
          final events = eventsList
              .map((e) => BetEvent.fromJson(e))
              .toList();

          print('✅ Parsed ${events.length} events');

          return {'success': true, 'events': events};
        } else {
          print('❌ No events key in response');
          return {
            'success': false, 
            'message': apiResponse.message.isNotEmpty 
                ? apiResponse.message 
                : 'No events found',
          };
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('❌ Error Body: ${response.body}');

        try {
          final errorResult = jsonDecode(response.body);
          final apiError = ApiResponse.fromJson(errorResult);
          return {
            'success': false,
            'message': apiError.message.isNotEmpty
                ? apiError.message
                : 'Failed to load events (${response.statusCode})',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to load events (${response.statusCode})',
          };
        }
      }
    } catch (e, stackTrace) {
      print('❌ Exception: $e');
      print('❌ Stack Trace: $stackTrace');
      return {'success': false, 'message': 'Server error: $e'};
    }
  }

  /// Place a bet
  Future<Map<String, dynamic>> placeBet({
    required int eventId,
    required int oddId,
    required double amount,
  }) async {
    final url = Uri.parse(Constants.placeBet);
    final authService = AuthService();
    final token = await authService.getToken();

    print('🔍 Calling: $url');
    print(
      '🔑 Token: ${token != null ? "${token.substring(0, 20)}..." : "null"}',
    );

    if (token == null || token.isEmpty) {
      print('❌ No token available');
      return {'success': false, 'message': 'Please login to place a bet'};
    }

    try {
      final requestBody = {
        'event_id': eventId,
        'odd_id': oddId,
        'amount': amount,
      };

      print('📤 Request Body: $requestBody');

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(result);
        print('✅ Bet placed successfully');

        // Handle new format: { success, data: { transaction, balance } } or old format
        dynamic transactionData;
        dynamic balanceData;
        
        if (apiResponse.data is Map) {
          transactionData = apiResponse.data['transaction'] ?? result['transaction'];
          balanceData = apiResponse.data['balance'] ?? result['balance'];
        } else {
          transactionData = result['transaction'];
          balanceData = result['balance'];
        }

        return {
          'success': true,
          'message': apiResponse.message.isNotEmpty 
              ? apiResponse.message 
              : 'Bet placed successfully',
          'transaction': transactionData != null 
              ? BetTransaction.fromJson(transactionData) 
              : null,
          'balance': balanceData,
        };
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('❌ Error Body: ${response.body}');

        try {
          final errorResult = jsonDecode(response.body);
          final apiError = ApiResponse.fromJson(errorResult);
          return {
            'success': false,
            'message': apiError.message.isNotEmpty 
                ? apiError.message 
                : 'Failed to place bet',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to place bet (${response.statusCode})',
          };
        }
      }
    } catch (e, stackTrace) {
      print('❌ Exception: $e');
      print('❌ Stack Trace: $stackTrace');
      return {'success': false, 'message': 'Server error: $e'};
    }
  }

  /// Get bet history
  Future<Map<String, dynamic>> getBetHistory({String? status}) async {
    var url = Constants.betHistory;
    if (status != null) {
      url += '?status=$status';
    }

    final authService = AuthService();
    final token = await authService.getToken();

    print('🔍 Calling: $url');
    print(
      '🔑 Token: ${token != null ? "${token.substring(0, 20)}..." : "null"}',
    );

    if (token == null || token.isEmpty) {
      print('❌ No token available');
      return {'success': false, 'message': 'Please login to view history'};
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(result);
        print('✅ Decoded Result: $result');

        // Handle both paginated and non-paginated responses
        // New format: { success, data: { transactions: [...] or { data: [...] } } }
        // Old format: { transactions: [...] or { data: [...] } }
        List<dynamic> transactionsList = [];

        // Check new format first (data.transactions)
        if (apiResponse.data is Map && apiResponse.data['transactions'] != null) {
          final transactions = apiResponse.data['transactions'];
          if (transactions is Map && transactions['data'] != null) {
            // Paginated response in new format
            transactionsList = transactions['data'];
          } else if (transactions is List) {
            // Non-paginated response in new format
            transactionsList = transactions;
          }
        } else if (result['transactions'] != null) {
          // Old format fallback
          if (result['transactions'] is Map &&
              result['transactions']['data'] != null) {
            // Paginated response
            transactionsList = result['transactions']['data'];
          } else if (result['transactions'] is List) {
            // Non-paginated response
            transactionsList = result['transactions'];
          }
        }

        final transactions = transactionsList
            .map((t) => BetTransaction.fromJson(t))
            .toList();

        print('✅ Parsed ${transactions.length} transactions');

        return {'success': true, 'transactions': transactions};
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('❌ Error Body: ${response.body}');

        try {
          final errorResult = jsonDecode(response.body);
          final apiError = ApiResponse.fromJson(errorResult);
          return {
            'success': false,
            'message': apiError.message.isNotEmpty
                ? apiError.message
                : 'Failed to load history (${response.statusCode})',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to load history (${response.statusCode})',
          };
        }
      }
    } catch (e, stackTrace) {
      print('❌ Exception: $e');
      print('❌ Stack Trace: $stackTrace');
      return {'success': false, 'message': 'Server error: $e'};
    }
  }

  /// Get bet statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final url = Uri.parse(Constants.betStatistics);
    final authService = AuthService();
    final token = await authService.getToken();

    print('🔍 Calling: $url');
    print(
      '🔑 Token: ${token != null ? "${token.substring(0, 20)}..." : "null"}',
    );

    if (token == null || token.isEmpty) {
      print('❌ No token available');
      return {'success': false, 'message': 'Please login to view statistics'};
    }

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(result);
        print('✅ Decoded Result: $result');

        // Handle new format: { success, data: { stats } } or old format: { stats }
        dynamic statsData;
        if (apiResponse.data is Map && apiResponse.data['stats'] != null) {
          statsData = apiResponse.data['stats'];
        } else if (result['stats'] != null) {
          statsData = result['stats'];
        }

        if (statsData != null) {
          return {'success': true, 'stats': statsData};
        } else {
          print('❌ No stats key in response');
          return {
            'success': false,
            'message': apiResponse.message.isNotEmpty 
                ? apiResponse.message 
                : 'No statistics found in response',
          };
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('❌ Error Body: ${response.body}');

        try {
          final errorResult = jsonDecode(response.body);
          final apiError = ApiResponse.fromJson(errorResult);
          return {
            'success': false,
            'message': apiError.message.isNotEmpty
                ? apiError.message
                : 'Failed to load statistics (${response.statusCode})',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to load statistics (${response.statusCode})',
          };
        }
      }
    } catch (e, stackTrace) {
      print('❌ Exception: $e');
      print('❌ Stack Trace: $stackTrace');
      return {'success': false, 'message': 'Server error: $e'};
    }
  }
}
