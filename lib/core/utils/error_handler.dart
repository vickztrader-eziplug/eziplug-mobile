import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized error handler that sanitizes error messages for production
/// 
/// In release builds:
/// - Network/socket errors show: "Network error. Please try again."
/// - Server errors (5xx) show: "Network error. Please try again."
/// - Client errors (4xx) show more specific user-friendly messages
/// 
/// In debug builds:
/// - Full error details are shown for debugging purposes
class ErrorHandler {
  /// Generic network error message for users
  static const String networkError = 'Network error. Please try again.';
  
  /// Generic server error message for users
  static const String serverError = 'Something went wrong. Please try again.';
  
  /// Check if we're in release mode
  static bool get isRelease => kReleaseMode;
  
  /// Sanitize an exception for user display
  /// In release mode, returns a generic user-friendly message
  /// In debug mode, returns the full exception details
  static String sanitizeException(dynamic exception) {
    // In debug mode, show full details for debugging
    if (!isRelease) {
      return 'Error: $exception';
    }
    
    // In release mode, show user-friendly messages
    if (_isNetworkError(exception)) {
      return networkError;
    }
    
    return serverError;
  }
  
  /// Get a user-friendly error message from an exception
  /// This is the main method to use when catching exceptions
  static String getUserFriendlyMessage(dynamic exception, {String? fallback}) {
    // In debug mode, show full details
    if (!isRelease) {
      return 'Error: $exception';
    }
    
    // Use fallback if provided, otherwise use generic message
    return fallback ?? networkError;
  }
  
  /// Check if an exception is a network-related error
  static bool _isNetworkError(dynamic exception) {
    final exceptionString = exception.toString().toLowerCase();
    
    return exception is SocketException ||
           exception is HttpException ||
           exceptionString.contains('socket') ||
           exceptionString.contains('connection') ||
           exceptionString.contains('network') ||
           exceptionString.contains('failed host lookup') ||
           exceptionString.contains('clientexception') ||
           exceptionString.contains('timeout') ||
           exceptionString.contains('no address associated');
  }
  
  /// Sanitize an API response message
  /// Removes sensitive information from server error messages
  static String sanitizeApiMessage(String message, {int? statusCode}) {
    // In debug mode, show full message
    if (!isRelease) {
      return message;
    }
    
    // For server errors (5xx), don't show technical details
    if (statusCode != null && statusCode >= 500) {
      return networkError;
    }
    
    // For certain patterns that indicate technical errors, sanitize
    final lowerMessage = message.toLowerCase();
    if (_containsTechnicalDetails(lowerMessage)) {
      return serverError;
    }
    
    // For 4xx errors with user-friendly messages, pass through
    return message;
  }
  
  /// Check if a message contains technical details that shouldn't be shown
  static bool _containsTechnicalDetails(String message) {
    return message.contains('exception') ||
           message.contains('stacktrace') ||
           message.contains('stack trace') ||
           message.contains('sqlstate') ||
           message.contains('unexpected response') ||
           message.contains('fatal error') ||
           message.contains('null pointer') ||
           message.contains('segmentation fault');
  }
  
  /// Log an error for debugging purposes (only in debug mode)
  static void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    if (!isRelease) {
      debugPrint('[$context] Error: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }
}
