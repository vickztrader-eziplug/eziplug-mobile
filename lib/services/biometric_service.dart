// lib/services/biometric_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cashpoint/services/api_client.dart';
import 'package:cashpoint/core/utils/constants.dart';
import 'package:cashpoint/services/debug_logger.dart';

/// Service for handling biometric authentication and app lock functionality.
/// 
/// This service provides:
/// - Fingerprint/Face ID authentication
/// - Fallback to transaction PIN after 3 failed biometric attempts
/// - Secure storage of biometric preferences
class BiometricService extends ChangeNotifier {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Storage keys
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _failedAttemptsKey = 'biometric_failed_attempts';
  
  // Configuration
  static const int maxFailedAttempts = 3;
  
  bool _isAvailable = false;
  bool _isEnabled = false;
  int _failedAttempts = 0;
  List<BiometricType> _availableBiometrics = [];
  
  bool get isAvailable => _isAvailable;
  bool get isEnabled => _isEnabled;
  int get failedAttempts => _failedAttempts;
  List<BiometricType> get availableBiometrics => _availableBiometrics;
  bool get shouldFallbackToPin => _failedAttempts >= maxFailedAttempts;
  
  /// Initialize the biometric service
  Future<void> init() async {
    try {
      // Check if the device supports biometrics
      _isAvailable = await _localAuth.canCheckBiometrics || 
                     await _localAuth.isDeviceSupported();
      
      if (_isAvailable) {
        // Get available biometric types
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
        await debugLogger.log('BIOMETRIC', 'Available biometrics: $_availableBiometrics');
      }
      
      // Load user preference
      final enabledStr = await _storage.read(key: _biometricEnabledKey);
      _isEnabled = enabledStr == 'true';
      
      // Load failed attempts
      final attemptsStr = await _storage.read(key: _failedAttemptsKey);
      _failedAttempts = int.tryParse(attemptsStr ?? '0') ?? 0;
      
      await debugLogger.log('BIOMETRIC', 'Initialized: available=$_isAvailable, enabled=$_isEnabled');
    } catch (e) {
      await debugLogger.log('BIOMETRIC_ERROR', 'Init failed: $e');
      _isAvailable = false;
    }
    notifyListeners();
  }
  
  /// Enable or disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
    notifyListeners();
  }
  
  /// Reset failed attempts counter (call after successful authentication)
  Future<void> resetFailedAttempts() async {
    _failedAttempts = 0;
    await _storage.write(key: _failedAttemptsKey, value: '0');
    notifyListeners();
  }
  
  /// Increment failed attempts counter
  Future<void> _incrementFailedAttempts() async {
    _failedAttempts++;
    await _storage.write(key: _failedAttemptsKey, value: _failedAttempts.toString());
    notifyListeners();
  }
  
  /// Get a user-friendly name for available biometric type
  String get biometricTypeName {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (_availableBiometrics.contains(BiometricType.strong)) {
      return 'Biometric';
    }
    return 'Biometric';
  }
  
  /// Authenticate using biometrics
  /// 
  /// Returns:
  /// - `true` if authentication succeeded
  /// - `false` if authentication failed
  /// - Throws exception on platform errors
  Future<BiometricResult> authenticate({
    String reason = 'Please authenticate to access Eziplug',
  }) async {
    if (!_isAvailable) {
      return BiometricResult(
        success: false,
        error: 'Biometric authentication is not available on this device',
        shouldFallbackToPin: true,
      );
    }
    
    if (shouldFallbackToPin) {
      return BiometricResult(
        success: false,
        error: 'Too many failed attempts. Please enter your PIN.',
        shouldFallbackToPin: true,
      );
    }
    
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
      
      if (authenticated) {
        await resetFailedAttempts();
        return BiometricResult(success: true);
      } else {
        await _incrementFailedAttempts();
        
        if (shouldFallbackToPin) {
          return BiometricResult(
            success: false,
            error: 'Too many failed attempts. Please enter your PIN.',
            shouldFallbackToPin: true,
          );
        }
        
        return BiometricResult(
          success: false,
          error: 'Authentication failed. ${maxFailedAttempts - _failedAttempts} attempts remaining.',
          attemptsRemaining: maxFailedAttempts - _failedAttempts,
        );
      }
    } on PlatformException catch (e) {
      await debugLogger.log('BIOMETRIC_ERROR', 'Platform exception: ${e.code} - ${e.message}');
      
      // Handle specific error codes
      if (e.code == 'NotAvailable' || e.code == 'NotEnrolled') {
        return BiometricResult(
          success: false,
          error: 'Biometric authentication is not set up on this device',
          shouldFallbackToPin: true,
        );
      } else if (e.code == 'LockedOut') {
        return BiometricResult(
          success: false,
          error: 'Too many failed attempts. Please enter your PIN.',
          shouldFallbackToPin: true,
        );
      } else if (e.code == 'PermanentlyLockedOut') {
        return BiometricResult(
          success: false,
          error: 'Biometric authentication is locked. Please enter your PIN.',
          shouldFallbackToPin: true,
        );
      }
      
      return BiometricResult(
        success: false,
        error: e.message ?? 'An error occurred during authentication',
        shouldFallbackToPin: true,
      );
    } catch (e) {
      await debugLogger.log('BIOMETRIC_ERROR', 'Unknown error: $e');
      return BiometricResult(
        success: false,
        error: 'An error occurred during authentication',
        shouldFallbackToPin: true,
      );
    }
  }
  
  /// Verify transaction PIN with the backend
  /// 
  /// This is used as a fallback when biometric authentication fails
  Future<PinVerificationResult> verifyPin(String pin, String token) async {
    try {
      await debugLogger.log('PIN_VERIFY', 'Verifying transaction PIN...');
      
      final response = await apiClient.post(
        Uri.parse('${Constants.baseUrl}/verify-pin'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'pin': pin}),
        timeout: const Duration(seconds: 30),
      );
      
      await debugLogger.log('PIN_VERIFY', 'Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final success = result['success'] == true;
        
        if (success) {
          await resetFailedAttempts();
          return PinVerificationResult(success: true, message: 'PIN verified successfully');
        } else {
          return PinVerificationResult(
            success: false, 
            message: result['message'] ?? 'Invalid PIN',
          );
        }
      } else if (response.statusCode == 401) {
        return PinVerificationResult(
          success: false,
          message: 'Session expired. Please login again.',
          sessionExpired: true,
        );
      } else {
        final result = jsonDecode(response.body);
        return PinVerificationResult(
          success: false,
          message: result['message'] ?? 'PIN verification failed',
        );
      }
    } catch (e) {
      await debugLogger.log('PIN_VERIFY_ERROR', 'Error: $e');
      return PinVerificationResult(
        success: false,
        message: 'Network error. Please try again.',
      );
    }
  }
  
  /// Clear all stored data (call on logout)
  Future<void> clear() async {
    _failedAttempts = 0;
    await _storage.delete(key: _failedAttemptsKey);
    notifyListeners();
  }
}

/// Result of biometric authentication attempt
class BiometricResult {
  final bool success;
  final String? error;
  final bool shouldFallbackToPin;
  final int? attemptsRemaining;
  
  BiometricResult({
    required this.success,
    this.error,
    this.shouldFallbackToPin = false,
    this.attemptsRemaining,
  });
}

/// Result of PIN verification
class PinVerificationResult {
  final bool success;
  final String message;
  final bool sessionExpired;
  
  PinVerificationResult({
    required this.success,
    required this.message,
    this.sessionExpired = false,
  });
}

// Global instance
final biometricService = BiometricService();
