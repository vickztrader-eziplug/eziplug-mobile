// lib/services/debug_logger.dart
// Cross-platform debug logger that works on mobile, desktop, and web
import 'package:flutter/foundation.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';

/// A simple debug logger that:
/// 1. Shows toast messages on screen (only in debug mode or for errors)
/// 2. Keeps logs in memory for viewing in a debug screen
/// Note: File logging disabled for web compatibility
class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  // In-memory log storage
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  // Only show debug toasts in debug mode (not release)
  // Errors will always show toasts through ToastHelper
  static bool showToasts = kDebugMode;

  /// Log a message with optional toast display
  Future<void> log(String tag, String message, {bool showToast = true}) async {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] [$tag] $message';
    
    // Add to in-memory list
    _logs.add(logEntry);
    if (_logs.length > 500) {
      _logs.removeAt(0); // Keep max 500 entries
    }

    // Print to console
    debugPrint(logEntry);

    // Show toast if enabled (not supported on web in the same way)
    if (showToasts && showToast && !kIsWeb) {
      Fluttertoast.showToast(
        msg: '[$tag] ${message.length > 100 ? '${message.substring(0, 100)}...' : message}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: _getColorForTag(tag),
        textColor: Colors.white,
        fontSize: 12.0,
      );
    }
  }

  Color _getColorForTag(String tag) {
    switch (tag.toUpperCase()) {
      case 'ERROR':
        return Colors.red;
      case 'SUCCESS':
        return Colors.green;
      case 'WARNING':
        return Colors.orange;
      case 'HTTP':
        return Colors.blue;
      default:
        return Colors.grey.shade800;
    }
  }

  /// Get the log file path (returns empty on web)
  Future<String> getLogFilePath() async {
    return 'In-memory logs only (web compatible)';
  }

  /// Read all logs from memory
  Future<String> readLogsFromFile() async {
    return _logs.isEmpty ? 'No logs available' : _logs.join('\n');
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    _logs.clear();
  }
}

// Global instance for easy access
final debugLogger = DebugLogger();
