import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/utils/constants.dart';
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
        print('✅ Decoded Result: $result');

        if (result['categories'] != null) {
          final categories = (result['categories'] as List)
              .map((c) => BetCategory.fromJson(c))
              .toList();

          print('✅ Parsed ${categories.length} categories');

          return {'success': true, 'categories': categories};
        } else {
          print('❌ No categories key in response');
          return {
            'success': false,
            'message': 'No categories found in response',
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
        print('✅ Decoded Result: $result');

        if (result['events'] != null) {
          final events = (result['events'] as List)
              .map((e) => BetEvent.fromJson(e))
              .toList();

          print('✅ Parsed ${events.length} events');

          return {'success': true, 'events': events};
        } else {
          print('❌ No events key in response');
          return {'success': false, 'message': 'No events found in response'};
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
                'Failed to load events (${response.statusCode})',
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
        print('✅ Decoded Result: $result');

        if (result['events'] != null) {
          final events = (result['events'] as List)
              .map((e) => BetEvent.fromJson(e))
              .toList();

          print('✅ Parsed ${events.length} events');

          return {'success': true, 'events': events};
        } else {
          print('❌ No events key in response');
          return {'success': false, 'message': 'No events found'};
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
                'Failed to load events (${response.statusCode})',
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
        print('✅ Bet placed successfully');

        return {
          'success': true,
          'message': result['message'] ?? 'Bet placed successfully',
          'transaction': BetTransaction.fromJson(result['transaction']),
          'balance': result['balance'],
        };
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('❌ Error Body: ${response.body}');

        try {
          final errorResult = jsonDecode(response.body);
          return {
            'success': false,
            'message': errorResult['message'] ?? 'Failed to place bet',
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
        print('✅ Decoded Result: $result');

        // Handle both paginated and non-paginated responses
        List<dynamic> transactionsList = [];

        if (result['transactions'] != null) {
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
          return {
            'success': false,
            'message':
                errorResult['message'] ??
                'Failed to load history (${response.statusCode})',
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
        print('✅ Decoded Result: $result');

        if (result['stats'] != null) {
          return {'success': true, 'stats': result['stats']};
        } else {
          print('❌ No stats key in response');
          return {
            'success': false,
            'message': 'No statistics found in response',
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
                'Failed to load statistics (${response.statusCode})',
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
