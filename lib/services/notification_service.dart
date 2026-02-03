import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/utils/constants.dart';
import 'auth_service.dart';
import 'debug_logger.dart';

/// Notification Model matching backend Notification structure
class NotificationItem {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final String formattedDate;
  final String formattedTime;
  final String timeAgo;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.data,
    required this.createdAt,
    required this.formattedDate,
    required this.formattedTime,
    required this.timeAgo,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'user',
      isRead: json['is_read'] == true,
      data: json['data'] is Map<String, dynamic> ? json['data'] : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      formattedDate: json['formatted_date'] ?? '',
      formattedTime: json['formatted_time'] ?? '',
      timeAgo: json['time_ago'] ?? '',
    );
  }

  /// Create a copy with updated isRead status
  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      data: data,
      createdAt: createdAt,
      formattedDate: formattedDate,
      formattedTime: formattedTime,
      timeAgo: timeAgo,
    );
  }
}

/// Response model for notifications list
class NotificationsResponse {
  final List<NotificationItem> notifications;
  final int unreadCount;
  final bool success;
  final String? message;

  NotificationsResponse({
    required this.notifications,
    required this.unreadCount,
    required this.success,
    this.message,
  });
}

/// Service to handle notification API calls
class NotificationService extends ChangeNotifier {
  final AuthService _authService;
  
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  NotificationService(this._authService);

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Get headers with authentication token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  /// Fetch notifications from the API
  Future<NotificationsResponse> fetchNotifications({int limit = 20}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${Constants.notifications}?limit=$limit');
      
      await debugLogger.log('NOTIFICATION', 'Fetching notifications: $uri', showToast: false);
      
      final response = await http.get(uri, headers: headers);
      
      await debugLogger.log('NOTIFICATION', 'Response status: ${response.statusCode}', showToast: false);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notificationsData = data['data']?['notifications'] ?? data['notifications'] ?? [];
        final unreadCount = data['data']?['unread_count'] ?? data['unread_count'] ?? 0;
        
        _notifications = (notificationsData as List)
            .map((json) => NotificationItem.fromJson(json))
            .toList();
        _unreadCount = unreadCount;
        _isLoading = false;
        notifyListeners();
        
        return NotificationsResponse(
          notifications: _notifications,
          unreadCount: _unreadCount,
          success: true,
        );
      } else {
        _errorMessage = 'Failed to fetch notifications';
        _isLoading = false;
        notifyListeners();
        
        return NotificationsResponse(
          notifications: [],
          unreadCount: 0,
          success: false,
          message: _errorMessage,
        );
      }
    } catch (e) {
      await debugLogger.log('NOTIFICATION_ERROR', 'Error fetching notifications: $e');
      _errorMessage = 'Error fetching notifications: $e';
      _isLoading = false;
      notifyListeners();
      
      return NotificationsResponse(
        notifications: [],
        unreadCount: 0,
        success: false,
        message: _errorMessage,
      );
    }
  }

  /// Fetch unread count only (lightweight call)
  Future<int> fetchUnreadCount() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(Constants.notificationsUnreadCount);
      
      final response = await http.get(uri, headers: headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Handle various response structures safely
        int count = 0;
        if (data is Map<String, dynamic>) {
          final dataField = data['data'];
          if (dataField is Map<String, dynamic>) {
            count = dataField['unread_count'] ?? 0;
          } else if (dataField is int) {
            count = dataField;
          } else if (data['unread_count'] is int) {
            count = data['unread_count'];
          }
        } else if (data is int) {
          count = data;
        }
        
        _unreadCount = count;
        notifyListeners();
        return _unreadCount;
      }
      return _unreadCount;
    } catch (e) {
      await debugLogger.log('NOTIFICATION_ERROR', 'Error fetching unread count: $e');
      return _unreadCount;
    }
  }

  /// Get a single notification and mark it as read
  Future<NotificationItem?> getNotification(int id) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${Constants.notifications}/$id');
      
      final response = await http.get(uri, headers: headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notificationData = data['data']?['notification'] ?? data['notification'];
        
        if (notificationData != null) {
          final notification = NotificationItem.fromJson(notificationData);
          
          // Update local state
          final index = _notifications.indexWhere((n) => n.id == id);
          if (index != -1 && !_notifications[index].isRead) {
            _notifications[index] = _notifications[index].copyWith(isRead: true);
            _unreadCount = (_unreadCount > 0) ? _unreadCount - 1 : 0;
            notifyListeners();
          }
          
          return notification;
        }
      }
      return null;
    } catch (e) {
      await debugLogger.log('NOTIFICATION_ERROR', 'Error getting notification: $e');
      return null;
    }
  }

  /// Mark a notification as read
  Future<bool> markAsRead(int id) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${Constants.notifications}/$id/mark-read');
      
      final response = await http.post(uri, headers: headers);
      
      if (response.statusCode == 200) {
        // Update local state
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1 && !_notifications[index].isRead) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          _unreadCount = (_unreadCount > 0) ? _unreadCount - 1 : 0;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      await debugLogger.log('NOTIFICATION_ERROR', 'Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(Constants.notificationsMarkAllRead);
      
      final response = await http.post(uri, headers: headers);
      
      if (response.statusCode == 200) {
        // Update local state
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
        _unreadCount = 0;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      await debugLogger.log('NOTIFICATION_ERROR', 'Error marking all as read: $e');
      return false;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(int id) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${Constants.notifications}/$id');
      
      final response = await http.delete(uri, headers: headers);
      
      if (response.statusCode == 200) {
        // Update local state
        final notification = _notifications.firstWhere(
          (n) => n.id == id,
          orElse: () => _notifications.first,
        );
        if (!notification.isRead) {
          _unreadCount = (_unreadCount > 0) ? _unreadCount - 1 : 0;
        }
        _notifications.removeWhere((n) => n.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      await debugLogger.log('NOTIFICATION_ERROR', 'Error deleting notification: $e');
      return false;
    }
  }

  /// Clear local notification data (on logout)
  void clear() {
    _notifications = [];
    _unreadCount = 0;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
