import 'dart:io';
import 'package:flutter/services.dart';

class ShareService {
  static const MethodChannel _channel = MethodChannel('com.cashpoint/share');

  static Future<void> shareFile(String filePath, String title) async {
    try {
      await _channel.invokeMethod('shareFile', {
        'path': filePath,
        'title': title,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to share: ${e.message}');
    }
  }
}