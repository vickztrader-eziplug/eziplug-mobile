import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../core/utils/constants.dart';
import 'auth_service.dart';
import 'debug_logger.dart';

/// Top-level background message handler.
/// Must be a top-level function (not a class method) for Firebase to invoke it
/// when the app is backgrounded or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: when a notification payload is present, Android will display it
  // automatically via the system tray. This handler is required to be
  // registered so that Firebase doesn't silently drop the message.
  debugPrint('[PUSH] Background message received: ${message.messageId}');
}

class PushNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final AuthService _authService;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Android notification channel — must match the one declared in AndroidManifest.xml
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'eziplug_notifications', // id
    'Eziplug Notifications', // name
    description: 'Push notifications from Eziplug',
    importance: Importance.high,
  );

  PushNotificationService(this._authService);

  /// Initialize Firebase Messaging, local notifications, and request permissions
  Future<void> initialize() async {
    // ── 1. Create the Android notification channel ──
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // ── 2. Initialize flutter_local_notifications ──
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      // Set to false: firebase_messaging handles permission requests.
      // Having both plugins request permissions can cause conflicts on iOS.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // ── 3. Request permission from user (required for iOS & Android 13+) ──
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugLogger.log(
          'PUSH', 'User granted permission for push notifications');

      // ── 4. Get the FCM token and send to backend ──
      String? token;
      if (!kIsWeb && Platform.isIOS) {
        // On iOS, we must wait for the APNs token before requesting FCM token.
        // Without this, getToken() can hang indefinitely.
        debugLogger.log('PUSH', 'iOS: Waiting for APNs token...');
        String? apnsToken;
        for (int i = 0; i < 20; i++) {
          apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
        if (apnsToken != null) {
          debugLogger.log('PUSH', 'iOS: APNs token received, requesting FCM token...');
          token = await _firebaseMessaging.getToken();
        } else {
          debugLogger.log('PUSH', 'iOS: APNs token not available, skipping FCM token for now');
        }
      } else {
        token = await _firebaseMessaging.getToken();
      }
      if (token != null) {
        debugLogger.log('PUSH', 'FCM Token: $token');
        await sendTokenToBackend(token);
      }

      // Any time the token refreshes, store this in the database too.
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        sendTokenToBackend(newToken);
      });

      // ── 5. Handle FOREGROUND messages ──
      // On Android, FCM does NOT show a system notification when the app is
      // in the foreground. We must display it ourselves via local notifications.
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // ── 6. Handle notification taps (background → opened) ──
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugLogger.log('PUSH', 'Message clicked! ${message.messageId}');
        // Navigate to appropriate screen based on message.data
      });

      // ── 7. Set foreground notification presentation options (iOS) ──
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } else {
      debugLogger.log(
          'PUSH', 'User declined or has not accepted permission');
    }
  }

  /// Display a foreground FCM message as a local heads-up notification.
  /// On iOS, the system handles foreground display via
  /// setForegroundNotificationPresentationOptions, so we only need this
  /// for Android (which does NOT auto-show foreground notifications).
  void _handleForegroundMessage(RemoteMessage message) {
    debugLogger.log('PUSH',
        'Received foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // On iOS, the system already displays the notification via
    // setForegroundNotificationPresentationOptions(alert: true).
    // Showing it again via flutter_local_notifications would cause duplicates.
    if (!kIsWeb && Platform.isIOS) return;

    _localNotifications.show(
      notification.hashCode, // unique id
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Called when user taps a local notification
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[PUSH] Notification tapped: ${response.payload}');
    // Navigate to appropriate screen based on payload data
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
        debugLogger.log(
            'PUSH', 'Successfully registered device token with backend');
      } else {
        debugLogger.log('PUSH_ERROR',
            'Failed to register device token. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugLogger.log(
          'PUSH_ERROR', 'Exception sending token to backend: $e');
    }
  }
}
