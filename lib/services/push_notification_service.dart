import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/utils/constants.dart';
import 'auth_service.dart';
import 'debug_logger.dart';

class PushNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final AuthService _authService;

  PushNotificationService(this._authService);

  /// Initialize Firebase Messaging and request permissions
  Future<void> initialize() async {
    // Request permission from user (required for iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugLogger.log('PUSH', 'User granted permission for push notifications');
      
      // Get the token each time the application loads
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugLogger.log('PUSH', 'FCM Token: $token');
        await sendTokenToBackend(token);
      }

      // Any time the token refreshes, store this in the database too.
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        sendTokenToBackend(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugLogger.log('PUSH', 'Received foreground message: ${message.notification?.title}');
        // Here you could optionally use flutter_local_notifications to display a heads-up notification
      });

      // Handle background/terminated state messages opened by user
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugLogger.log('PUSH', 'Message clicked! ${message.messageId}');
        // Navigate to appropriate screen based on message.data
      });
    } else {
      debugLogger.log('PUSH', 'User declined or has not accepted permission');
    }
  }

  /// Send the FCM token to the backend
  Future<void> sendTokenToBackend(String token) async {
    try {
      final authToken = await _authService.getToken();
      if (authToken == null || authToken.isEmpty) return; // User not logged in

      final uri = Uri.parse('${Constants.baseUrl}/user/device-token');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'device_token': token,
        }),
      );

      if (response.statusCode == 200) {
        debugLogger.log('PUSH', 'Successfully registered device token with backend');
      } else {
        debugLogger.log('PUSH_ERROR', 'Failed to register device token. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugLogger.log('PUSH_ERROR', 'Exception sending token to backend: $e');
    }
  }
}
