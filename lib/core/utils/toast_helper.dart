import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'error_handler.dart';

/// Centralized Toast Helper for consistent toast notifications
/// 
/// Features:
/// - Shows at TOP of screen for better visibility
/// - Red for errors, Green for success, Orange for warnings
/// - Handles HTTP status codes appropriately:
///   - 500: Shows "Network error" (doesn't expose server details)
///   - 400: Shows the actual error message
/// - Longer duration for user to read
class ToastHelper {
  // Duration for toasts (longer for better readability)
  static const Toast _defaultDuration = Toast.LENGTH_LONG;
  static const int _timeInSecForIosWeb = 4; // 4 seconds for iOS/Web
  
  // Colors
  static const Color successColor = Color(0xFF4CAF50); // Green
  static const Color errorColor = Color(0xFFE53935); // Red
  static const Color warningColor = Color(0xFFFF9800); // Orange
  static const Color infoColor = Color(0xFF2196F3); // Blue

  /// Show a success toast (green)
  static void showSuccess(String message) {
    _showToast(
      message: message,
      backgroundColor: successColor,
      icon: Icons.check_circle_outline,
    );
  }

  /// Show an error toast (red)
  static void showError(String message) {
    _showToast(
      message: message,
      backgroundColor: errorColor,
      icon: Icons.error_outline,
    );
  }

  /// Show a warning toast (orange)
  static void showWarning(String message) {
    _showToast(
      message: message,
      backgroundColor: warningColor,
      icon: Icons.warning_amber_outlined,
    );
  }

  /// Show an info toast (blue)
  static void showInfo(String message) {
    _showToast(
      message: message,
      backgroundColor: infoColor,
      icon: Icons.info_outline,
    );
  }
  
  /// Show an exception error with sanitized message for production
  /// In release mode: Shows generic "Network error" message
  /// In debug mode: Shows full exception details for debugging
  static void showException(dynamic exception, {String? fallback}) {
    final message = ErrorHandler.getUserFriendlyMessage(exception, fallback: fallback);
    showError(message);
  }
  
  /// Show an exception error with SnackBar (context-based)
  static void showExceptionSnackBar(BuildContext context, dynamic exception, {String? fallback}) {
    final message = ErrorHandler.getUserFriendlyMessage(exception, fallback: fallback);
    showErrorSnackBar(context, message);
  }

  /// Handle HTTP error responses appropriately
  /// - 500+ errors: Show generic "Network error"
  /// - 400-499 errors: Show the actual message
  /// - Other errors: Show the message as is
  static void showHttpError({
    required int statusCode,
    String? message,
  }) {
    if (statusCode >= 500) {
      // Server errors - don't expose details
      showError('Network error. Please try again later.');
    } else if (statusCode >= 400 && statusCode < 500) {
      // Client errors - show the message
      showError(message ?? 'Request failed. Please try again.');
    } else {
      // Other errors
      showError(message ?? 'An error occurred. Please try again.');
    }
  }

  /// Show toast based on API response success status
  static void showApiResponse({
    required bool success,
    required String message,
    int? statusCode,
  }) {
    if (success) {
      showSuccess(message);
    } else {
      if (statusCode != null && statusCode >= 500) {
        showError('Network error. Please try again later.');
      } else {
        showError(message);
      }
    }
  }

  /// Core toast display method
  static void _showToast({
    required String message,
    required Color backgroundColor,
    IconData? icon,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: _defaultDuration,
      gravity: ToastGravity.TOP, // Always show at TOP
      timeInSecForIosWeb: _timeInSecForIosWeb,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  /// Show a custom toast with specific color
  static void showCustom({
    required String message,
    required Color backgroundColor,
    ToastGravity gravity = ToastGravity.TOP,
    Toast duration = _defaultDuration,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: duration,
      gravity: gravity,
      timeInSecForIosWeb: _timeInSecForIosWeb,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  /// Cancel all toasts
  static void cancel() {
    Fluttertoast.cancel();
  }
  
  // ============================================
  // Context-based SnackBar methods (for screens that need BuildContext)
  // These show at the TOP of the screen with proper duration
  // ============================================
  
  /// Show a success SnackBar (green) at TOP
  static void showSuccessSnackBar(BuildContext context, String message) {
    _showSnackBar(context, message, successColor);
  }
  
  /// Show an error SnackBar (red) at TOP
  static void showErrorSnackBar(BuildContext context, String message) {
    _showSnackBar(context, message, errorColor);
  }
  
  /// Show a warning SnackBar (orange) at TOP
  static void showWarningSnackBar(BuildContext context, String message) {
    _showSnackBar(context, message, warningColor);
  }
  
  /// Show an info SnackBar (blue) at TOP
  static void showInfoSnackBar(BuildContext context, String message) {
    _showSnackBar(context, message, infoColor);
  }
  
  /// Handle HTTP error with SnackBar
  static void showHttpErrorSnackBar(BuildContext context, {
    required int statusCode,
    String? message,
  }) {
    if (statusCode >= 500) {
      showErrorSnackBar(context, 'Network error. Please try again later.');
    } else if (statusCode >= 400 && statusCode < 500) {
      showErrorSnackBar(context, message ?? 'Request failed. Please try again.');
    } else {
      showErrorSnackBar(context, message ?? 'An error occurred. Please try again.');
    }
  }
  
  /// Core SnackBar display method - shows at TOP with proper duration
  static void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == successColor ? Icons.check_circle_outline :
              color == errorColor ? Icons.error_outline :
              color == warningColor ? Icons.warning_amber_outlined :
              Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 0,
          left: 16,
          right: 16,
          top: 16,
        ),
        duration: const Duration(seconds: 4), // 4 seconds for better readability
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        dismissDirection: DismissDirection.up,
      ),
    );
  }
  
  /// Utility method for existing screens to migrate gradually
  /// Just pass message and color, shows at top with proper styling
  static void showSnackBar(BuildContext context, String message, Color color) {
    _showSnackBar(context, message, color);
  }
}
