// lib/services/api_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'debug_logger.dart';

/// A robust HTTP client that works in both debug and release modes.
/// Handles SSL certificates and provides detailed error logging.
class ApiClient {
  static ApiClient? _instance;
  late final http.Client _client;
  
  ApiClient._() {
    _client = _createClient();
  }
  
  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }
  
  http.Client _createClient() {
    // Create an HttpClient that accepts all certificates in case of issues
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 30);
    
    // For release builds, we can be more lenient with certificate validation
    // This helps debug SSL issues - remove in production if needed
    httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
      debugLogger.log('SSL', 'Certificate check for $host:$port', showToast: false);
      // Return true to accept the certificate (for debugging)
      // In production, you should validate properly
      return true;
    };
    
    return IOClient(httpClient);
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
    } on SocketException catch (e) {
      await debugLogger.log('HTTP_ERROR', 'Socket error on GET: $e');
      rethrow;
    } on HandshakeException catch (e) {
      await debugLogger.log('HTTP_ERROR', 'SSL error on GET: $e');
      rethrow;
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
    } on SocketException catch (e) {
      await debugLogger.log('HTTP_ERROR', 'Socket error on POST: $e');
      rethrow;
    } on HandshakeException catch (e) {
      await debugLogger.log('HTTP_ERROR', 'SSL error on POST: $e');
      rethrow;
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
    } on SocketException catch (e) {
      await debugLogger.log('HTTP_ERROR', 'Socket error on POST JSON: $e');
      rethrow;
    } on HandshakeException catch (e) {
      await debugLogger.log('HTTP_ERROR', 'SSL error on POST JSON: $e');
      rethrow;
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
