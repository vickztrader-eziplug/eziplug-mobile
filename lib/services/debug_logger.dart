// lib/services/debug_logger.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// A simple debug logger that:
/// 1. Shows toast messages on screen
/// 2. Writes logs to a file on the device
/// 3. Keeps logs in memory for viewing in a debug screen
class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  // In-memory log storage
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  // Enable/disable visual toasts (set to false in production)
  static bool showToasts = true;

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

    // Show toast if enabled
    if (showToasts && showToast) {
      Fluttertoast.showToast(
        msg: '[$tag] ${message.length > 100 ? '${message.substring(0, 100)}...' : message}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: _getColorForTag(tag),
        textColor: Colors.white,
        fontSize: 12.0,
      );
    }

    // Write to file
    await _writeToFile(logEntry);
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

  Future<void> _writeToFile(String logEntry) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/eziplug_debug.log');
      await file.writeAsString('$logEntry\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write log to file: $e');
    }
  }

  /// Get the log file path
  Future<String> getLogFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/eziplug_debug.log';
  }

  /// Read all logs from file
  Future<String> readLogsFromFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/eziplug_debug.log');
      if (await file.exists()) {
        return await file.readAsString();
      }
      return 'No logs found';
    } catch (e) {
      return 'Error reading logs: $e';
    }
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    _logs.clear();
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/eziplug_debug.log');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to clear log file: $e');
    }
  }
}

// Global instance for easy access
final debugLogger = DebugLogger();
