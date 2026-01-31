// lib/services/api_client.dart
// Cross-platform HTTP client that works on mobile, desktop, and web
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'debug_logger.dart';

/// A simple HTTP client wrapper that works across all platforms.
/// Uses the standard http package which is cross-platform compatible.
class ApiClient {
  static ApiClient? _instance;
  late final http.Client _client;
  
  ApiClient._() {
    // Standard http.Client works on all platforms including web
    _client = http.Client();
  }
  
  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }
  
  /// Make a GET request
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      await debugLogger.log('HTTP', 'GET: $url', showToast: false);
      final response = await _client.get(url, headers: headers).timeout(timeout);
      await debugLogger.log('HTTP', 'GET ${url.path}: ${response.statusCode}', showToast: false);
      return response;
    } on TimeoutException catch (e) {
      await debugLogger.log('HTTP_ERROR', 'Timeout on GET: $e');
      rethrow;
    } catch (e) {
      await debugLogger.log('HTTP_ERROR', 'GET error: ${e.runtimeType}: $e');
      rethrow;
    }
  }
  
  /// Make a POST request
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      await debugLogger.log('HTTP', 'POST: $url', showToast: false);
      final response = await _client.post(
        url,
        headers: headers,
        body: body,
      ).timeout(timeout);
      await debugLogger.log('HTTP', 'POST ${url.path}: ${response.statusCode}', showToast: false);
      return response;
    } on TimeoutException catch (e) {
      await debugLogger.log('HTTP_ERROR', 'Timeout on POST: $e');
      rethrow;
    } catch (e) {
      await debugLogger.log('HTTP_ERROR', 'POST error: ${e.runtimeType}: $e');
      rethrow;
    }
  }
  
  /// Make a POST request with JSON body
  Future<http.Response> postJson(
    Uri url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final jsonHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };
    
    try {
      await debugLogger.log('HTTP', 'POST JSON: $url', showToast: false);
      final response = await _client.post(
        url,
        headers: jsonHeaders,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(timeout);
      await debugLogger.log('HTTP', 'POST JSON ${url.path}: ${response.statusCode}', showToast: false);
      return response;
    } on TimeoutException catch (e) {
      await debugLogger.log('HTTP_ERROR', 'Timeout on POST JSON: $e');
      rethrow;
    } catch (e) {
      await debugLogger.log('HTTP_ERROR', 'POST JSON error: ${e.runtimeType}: $e');
      rethrow;
    }
  }
  
  void dispose() {
    _client.close();
    _instance = null;
  }
}

/// Global instance for easy access
final apiClient = ApiClient.instance;
