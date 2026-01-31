// lib/services/auth_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:cashpoint/core/utils/constants.dart';
import 'package:cashpoint/core/utils/api_response.dart';import 'package:cashpoint/services/debug_logger.dart';import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const String baseUrl = Constants.baseUrl;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Map<String, dynamic>? _user;
  bool _isAuthenticated = false;
  bool _hasCompletedOnboarding = false;
  bool _isInitialized = false;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get isInitialized => _isInitialized;

  String? _token;

  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;

  Map<String, dynamic>? get _userData => _user;
  String get userName => _userData?['first_name'] ?? _userData?['firstName'] ?? 'User';
  String get userLastName => _userData?['last_name'] ?? _userData?['lastName'] ?? '';
  String get userFullName {
    final first = userName;
    final last = userLastName;
    return last.isNotEmpty ? '$first $last' : first;
  }
  String get userEmail => _userData?['email'] ?? '';
  String get userPhone => _userData?['phone'] ?? '';
  String? get savedEmail => _user?['email'];
  String get userProfilePicture =>
      _userData?['profile'] ?? _userData?['avatar'] ?? _userData?['passport'] ?? '';
  double get walletNaira =>
      double.tryParse(_userData?['wallet_naira']?.toString() ?? '0') ?? 0.0;
  double get walletDollar =>
      double.tryParse(_userData?['wallet_usd']?.toString() ?? '0') ?? 0.0;

  Future<void> initAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
      final userDataString = prefs.getString('userData');

      // ✅ ADD ONLY THIS LINE - load onboarding status
      _hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;

      if (userDataString != null) {
        _user = jsonDecode(userDataString);
      }

      // Check if token is valid (you may already have this)
      if (_token != null && _token!.isNotEmpty) {
        await checkAuth();
      }
    } catch (e) {
      // If anything fails during init, continue anyway
      debugPrint('Error during initAuth: $e');
    } finally {
      // ✅ Always mark as initialized, even if there were errors
      _isInitialized = true;
      notifyListeners();
    }
  }
  // Future<void> initAuth() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   _token = prefs.getString('token');
  //   final userDataString = prefs.getString('userData');

  //   if (userDataString != null) {
  //     _user = jsonDecode(userDataString);
  //   }
  //   notifyListeners();
  // }

  /// Register - robust to different response shapes
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/register');

    try {
      await debugLogger.log('HTTP', 'Register request to: $url');
      await debugLogger.log('HTTP', 'Register data: ${data.keys.join(', ')}', showToast: false);
      
      final response = await http.post(
        url,
        headers: {'Accept': 'application/json'},
        body: data,
      ).timeout(const Duration(seconds: 60));

      await debugLogger.log('HTTP', 'Register status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(result);
        await debugLogger.log('SUCCESS', 'Register successful');

        // If registration returns a token, save it
        if (apiResponse.token != null) {
          await _saveAuth(result);
        }

        return {
          'success': apiResponse.success,
          'message': apiResponse.message.isNotEmpty ? apiResponse.message : 'Registration successful',
          'token': apiResponse.token,
          'user': apiResponse.user,
        };
      } else if (response.statusCode == 302) {
        await debugLogger.log('WARNING', 'Register 302 redirect');
        return {
          'success': false,
          'message': 'Email or phone number already exists.',
        };
      } else if (response.statusCode == 422) {
        final result = jsonDecode(response.body);
        final errors = result['errors'] ?? {};
        final message = result['message'] ?? 'Validation failed';
        await debugLogger.log('ERROR', 'Register 422: $message');

        // Return errors separately so UI can display them inline
        return {
          'success': false, 
          'message': message,
          'errors': errors,
        };
      } else if (response.statusCode == 401) {
        final result = jsonDecode(response.body);
        await debugLogger.log('ERROR', 'Register 401: Unauthorized');
        return {
          'success': false,
          'message': result['message'] ?? 'Unauthorized',
        };
      } else {
        await debugLogger.log('ERROR', 'Register unexpected: ${response.statusCode}');
        return {
          'success': false,
          'message':
              'Unexpected response (${response.statusCode}): ${response.body}',
        };
      }
    } catch (e, stackTrace) {
      await debugLogger.log('ERROR', 'Register exception: $e');
      debugPrint('Stack trace: $stackTrace');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
  //   final url = Uri.parse('$baseUrl/register');

  //   try {
  //     final response = await http.post(
  //       url,
  //       headers: {'Accept': 'application/json'},
  //       body: data,
  //     );

  //     print('Response status: ${response.statusCode}');
  //     print('Response body: ${response.body}');

  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       final result = jsonDecode(response.body);

  //       // If registration returns a token, save it
  //       if (result.containsKey('token')) {
  //         await _saveAuth(result);
  //       }

  //       // Return structure matching what the UI expects
  //       return {
  //         'status':
  //             result['status'] == true, // Changed from 'success' to 'status'
  //         'message': result['message'] ?? 'Registration successful',
  //         'results': {
  //           // Wrap token in 'results' object
  //           'token': result['token'],
  //           'user': result['user'],
  //         },
  //       };
  //     } else if (response.statusCode == 302) {
  //       return {
  //         'status': false, // Changed from 'success' to 'status'
  //         'message': 'Email or phone number already exists.',
  //       };
  //     } else if (response.statusCode == 422) {
  //       final result = jsonDecode(response.body);
  //       final errors = result['errors'] ?? {};
  //       final message = result['message'] ?? 'Validation failed';

  //       // Combine field-specific errors
  //       String combinedErrors = errors.entries
  //           .map((e) => '${e.key}: ${e.value.join(', ')}')
  //           .join('\n');

  //       return {
  //         'status': false, // Changed from 'success' to 'status'
  //         'message': '$message\n$combinedErrors',
  //       };
  //     } else {
  //       return {
  //         'status': false, // Changed from 'success' to 'status'
  //         'message':
  //             'Unexpected response (${response.statusCode}): ${response.body}',
  //       };
  //     }
  //   } catch (e) {
  //     print('Registration exception: $e');
  //     return {
  //       'status': false, // Changed from 'success' to 'status'
  //       'message': 'Server error: $e',
  //     };
  //   }
  // }

  /// Login - expects token (similar robust handling)
  Future<Map<String, dynamic>> login(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/login');

    try {
      await debugLogger.log('HTTP', 'Login request to: $url');
      
      final response = await http.post(
        url,
        headers: {'Accept': 'application/json'},
        body: data,
      ).timeout(const Duration(seconds: 60));

      final statusCode = response.statusCode;
      final body = response.body;
      
      await debugLogger.log('HTTP', 'Login status: $statusCode');

      if (statusCode == 200 || statusCode == 201) {
        final result = jsonDecode(body);
        final apiResponse = ApiResponse.fromJson(result);
        await debugLogger.log('SUCCESS', 'Login parsed, success: ${apiResponse.success}');
        
        if (apiResponse.success) {
          await _saveAuth(result);
          
          // Check if email is verified - handle both formats
          Map<String, dynamic>? userData = apiResponse.user;
          
          // If user is null, the data might BE the user (single element extraction)
          if (userData == null && apiResponse.data is Map<String, dynamic>) {
            final dataMap = apiResponse.data as Map<String, dynamic>;
            if (dataMap.containsKey('email') && dataMap.containsKey('id')) {
              // Data is the user object itself
              userData = dataMap;
            }
          }
          
          final isEmailVerified = userData?['email_verified_at'] != null;
          await debugLogger.log('SUCCESS', 'Email verified: $isEmailVerified');
          
          return {
            'success': true,
            'message': apiResponse.message.isNotEmpty ? apiResponse.message : 'Login successful',
            'user': userData,
            'token': apiResponse.token,
            'isEmailVerified': isEmailVerified,
          };
        } else {
          await debugLogger.log('WARNING', 'Login failed: ${apiResponse.message}');
          return {
            'success': false,
            'message': apiResponse.message.isNotEmpty ? apiResponse.message : 'Invalid credentials',
          };
        }
      }
      // Handle Laravel validation errors (422)
      else if (statusCode == 422) {
        final result = jsonDecode(body);
        await debugLogger.log('ERROR', 'Login 422: Validation error');
        final errors = result['errors'] ?? {};
        final message = result['message'] ?? 'Validation failed';
        // Combine field-specific errors
        String combinedErrors = errors.entries
            .map((e) => '${e.key}: ${e.value.join(', ')}')
            .join('\n');

        return {
          'success': false, 
          'message': '$message\n$combinedErrors',
          'errors': errors,
        };
      } else if (statusCode == 401) {
        final result = jsonDecode(body);
        await debugLogger.log('ERROR', 'Login 401: Invalid credentials');
        return {
          'success': false,
          'message': result['message'] ?? 'Invalid credentials',
        };
      } else if (statusCode == 302) {
        await debugLogger.log('ERROR', 'Login 302: Unexpected redirect');
        return {
          'success': false,
          'message':
              'Unexpected redirect (302). Confirm your API routes use api.php, not web.php.',
        };
      } else {
        await debugLogger.log('ERROR', 'Login unexpected: $statusCode');
        return {
          'success': false,
          'message': 'Unexpected response ($statusCode): $body',
        };
      }
    } catch (e, stackTrace) {
      await debugLogger.log('ERROR', 'Login exception: $e');
      debugPrint('Stack trace: $stackTrace');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Verify OTP after registration
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
    String? token,
  }) async {
    final url = Uri.parse('$baseUrl/verify');

    try {
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      // Add Authorization header with token
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Convert OTP string to integer
      final otpInt = int.tryParse(otp);
      if (otpInt == null) {
        return {'success': false, 'message': 'Invalid OTP format'};
      }

      final requestBody = {'otp': otpInt};

      print('=== VERIFY OTP REQUEST ===');
      print('URL: $url');
      print('Headers: $headers');
      print('Body: ${jsonEncode(requestBody)}');
      print('========================');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      print('=== VERIFY OTP RESPONSE ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('==========================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(result);

        print('Parsed Result: $result');
        print('Success: ${apiResponse.success}');
        print('Message: ${apiResponse.message}');

        return {
          'success': apiResponse.success,
          'message': apiResponse.message.isNotEmpty ? apiResponse.message : 'Verification successful',
          'user': apiResponse.user,
        };
      } else if (response.statusCode == 401) {
        try {
          final result = jsonDecode(response.body);
          return {
            'success': false,
            'message':
                result['message'] ??
                'Unauthenticated. Token may be invalid or expired.',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Unauthenticated. Token may be invalid or expired.',
          };
        }
      } else if (response.statusCode == 422) {
        try {
          final result = jsonDecode(response.body);
          return {
            'success': false,
            'message': result['message'] ?? 'Invalid OTP',
          };
        } catch (e) {
          return {'success': false, 'message': 'Invalid OTP'};
        }
      } else if (response.statusCode == 400) {
        try {
          final result = jsonDecode(response.body);
          return {
            'success': false,
            'message': result['message'] ?? 'Bad request',
          };
        } catch (e) {
          return {'success': false, 'message': 'Bad request'};
        }
      } else {
        try {
          final result = jsonDecode(response.body);
          return {
            'success': false,
            'message':
                result['message'] ??
                'Verification failed (${response.statusCode})',
          };
        } catch (e) {
          return {
            'success': false,
            'message':
                'Verification failed (${response.statusCode}): ${response.body}',
          };
        }
      }
    } catch (e) {
      print('Verify OTP Exception: $e');
      print('Exception Stack Trace: ${StackTrace.current}');
      return {'success': false, 'message': 'Server error: $e'};
    }
  }

  /// Forgot Password - Send OTP to email
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final url = Uri.parse('$baseUrl/reset/otp');

    try {
      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(result);
        return {
          'success': apiResponse.success,
          'message': apiResponse.message.isNotEmpty ? apiResponse.message : 'OTP sent to your email',
        };
      } else if (response.statusCode == 422) {
        final result = jsonDecode(response.body);
        final errors = result['errors'] ?? {};
        final message = result['message'] ?? 'Validation failed';

        String combinedErrors = errors.entries
            .map((e) => '${e.key}: ${e.value.join(', ')}')
            .join('\n');

        return {'success': false, 'message': '$message\n$combinedErrors'};
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Email not found'};
      } else {
        return {
          'success': false,
          'message': 'Failed to send OTP (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Server error: $e'};
    }
  }

  /// Reset Password with OTP
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    final url = Uri.parse('$baseUrl/reset/password');

    try {
      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(result);
        return {
          'success': apiResponse.success,
          'message': apiResponse.message.isNotEmpty ? apiResponse.message : 'Password reset successful',
        };
      } else if (response.statusCode == 422) {
        final result = jsonDecode(response.body);
        final errors = result['errors'] ?? {};
        final message = result['message'] ?? 'Validation failed';

        String combinedErrors = errors.entries
            .map((e) => '${e.key}: ${e.value.join(', ')}')
            .join('\n');

        return {'success': false, 'message': '$message\n$combinedErrors'};
      } else if (response.statusCode == 400) {
        final result = jsonDecode(response.body);
        return {
          'success': false,
          'message': result['message'] ?? 'Invalid OTP or expired',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to reset password (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Server error: $e'};
    }
  }

  /// Resend OTP
  Future<Map<String, dynamic>> resendOtp({
    required String email,
    String? token,
  }) async {
    final url = Uri.parse('$baseUrl/resend');

    try {
      await debugLogger.log('HTTP', 'Resend OTP to: $email');
      
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'email': email, 'type': 'verification'}),
      ).timeout(const Duration(seconds: 30));

      await debugLogger.log('HTTP', 'Resend OTP status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(result);
        await debugLogger.log('SUCCESS', 'OTP resent successfully');

        return {
          'success': apiResponse.success,
          'message': apiResponse.message == 'app.otp_resend'
              ? 'OTP resent successfully to your email'
              : (apiResponse.message.isNotEmpty ? apiResponse.message : 'OTP resent successfully'),
        };
      } else if (response.statusCode == 401) {
        await debugLogger.log('ERROR', 'Resend OTP 401: Session expired');
        return {
          'success': false,
          'message': 'Session expired. Please register again.',
        };
      } else if (response.statusCode == 422) {
        final result = jsonDecode(response.body);
        await debugLogger.log('ERROR', 'Resend OTP 422: ${result['message']}');
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to resend OTP',
        };
      } else if (response.statusCode == 429) {
        await debugLogger.log('WARNING', 'Resend OTP 429: Too many requests');
        return {
          'success': false,
          'message': 'Too many requests. Please try again later.',
        };
      } else {
        final result = jsonDecode(response.body);
        await debugLogger.log('ERROR', 'Resend OTP failed: ${response.statusCode}');
        return {
          'success': false,
          'message':
              result['message'] ??
              'Failed to resend OTP (${response.statusCode})',
        };
      }
    } catch (e) {
      await debugLogger.log('ERROR', 'Resend OTP exception: $e');
      return {'success': false, 'message': 'Server error: $e'};
    }
  }

  /// Save token & user to secure storage and memory
  // Future<void> _saveAuth(Map<String, dynamic> payload) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final token = payload['results']['token'] as String?;
  //   final user = payload['user'] as Map<String, dynamic>?;

  //   if (token != null) {
  //     _token = token;
  //     await _storage.write(key: 'token', value: token);
  //     await prefs.setString('token', _token!);
  //     await prefs.setString('userData', jsonEncode(_userData));
  //   }
  //   if (user != null) {
  //     _user = user;
  //     await _storage.write(key: 'user', value: jsonEncode(user));
  //     await prefs.setString('token', _token!);
  //     await prefs.setString('userData', jsonEncode(_userData));
  //   }

  //   _isAuthenticated = token != null;
  //   notifyListeners();
  // }
  Future<void> _saveAuth(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final apiResponse = ApiResponse.fromJson(payload);
    
    // Get token from new format (data.token) or old format (results.token)
    final token = apiResponse.token ?? payload['results']?['token'] as String?;
    // Get user from new format (data.user) or old format (user)
    final user = apiResponse.user ?? payload['user'] as Map<String, dynamic>?;

    if (token != null) {
      _token = token;
      await _storage.write(key: 'token', value: token);
      await prefs.setString('token', _token!);
    }

    if (user != null) {
      _user = user;
      await _storage.write(key: 'user', value: jsonEncode(user));
      await prefs.setString('userData', jsonEncode(user));

      // ✅ ADD ONLY THESE LINES - mark onboarding as completed on first login
      if (!_hasCompletedOnboarding) {
        _hasCompletedOnboarding = true;
        await prefs.setBool('hasCompletedOnboarding', true);
      }
    }

    _isAuthenticated = token != null;
    notifyListeners();
  }

  /// Mark onboarding as completed (call this from your onboarding screen)
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedOnboarding', true);
    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  /// Get Token from storage
  Future<String?> getToken() async {
    if (_token != null) return _token;

    final token = await _storage.read(key: 'token');
    _token = token;
    return token;
  }

  Future<String?> getToken2() async {
    if (_token != null) return _token;

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    return _token;
  }

  /// Get User from storage
  Future<Map<String, dynamic>?> getUser() async {
    if (_user != null) return _user;

    final userStr = await _storage.read(key: 'user');
    if (userStr != null) {
      _user = jsonDecode(userStr);
    }
    return _user;
  }

  Future<bool> refreshUserData() async {
    if (_token == null || _token!.isEmpty) return false;

    try {
      final response = await http.get(
        Uri.parse(Constants.user),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _user = data;

        // Update stored data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(_user));

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error refreshing user data: $e');
      return false;
    }
  }

  /// Check persisted auth (called at app startup)
  Future<void> checkAuth() async {
    final token = await _storage.read(key: 'token');
    if (token != null) {
      _token = token;
      final url = Uri.parse('$baseUrl/user');

      try {
        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);

          // Handle different response structures
          Map<String, dynamic>? user;
          
          // Check for standardized API response: { success: true, data: { ...user } }
          if (result.containsKey('success') && result['success'] == true && result.containsKey('data')) {
            final data = result['data'];
            if (data is Map) {
              // Data could be the user object directly or contain a 'user' key
              if (data.containsKey('user') && data['user'] is Map) {
                user = Map<String, dynamic>.from(data['user']);
              } else if (data.containsKey('id')) {
                // Data is the user object itself
                user = Map<String, dynamic>.from(data);
              }
            }
          }
          // Fallback: Check for { user: { ... } } format
          else if (result.containsKey('user') && result['user'] is Map) {
            user = Map<String, dynamic>.from(result['user']);
          } 
          // Fallback: Check for { result: { user: { ... } } } format
          else if (result.containsKey('result') && result['result'] is Map) {
            final res = result['result'] as Map;
            if (res.containsKey('user') && res['user'] is Map) {
              user = Map<String, dynamic>.from(res['user']);
            }
          } 
          // Fallback: If response is the user object itself
          else if (result is Map && result.containsKey('id')) {
            user = Map<String, dynamic>.from(result);
          }

          if (user != null) {
            _user = user;
            _isAuthenticated = true;
            notifyListeners();
          } else {
            debugPrint('checkAuth: Could not parse user from response: $result');
            await _clearAuth();
          }
        } else {
          await _clearAuth();
        }
      } catch (e) {
        debugPrint('checkAuth error: $e');
        // Don't clear auth on timeout - user might just have poor connection
        // Only clear if it's an auth error
        if (e is! TimeoutException) {
          await _clearAuth();
        }
      }
    }
  }

  /// Clear authentication
  Future<void> _clearAuth() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userData');

    // ✅ IMPORTANT: Keep onboarding status so user doesn't see it again
    // Only remove token and user data, NOT hasCompletedOnboarding

    _token = null;
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }
  // Future<void> _clearAuth() async {
  //   await _storage.delete(key: 'token');
  //   await _storage.delete(key: 'user');
  //   _token = null;
  //   _user = null;
  //   _isAuthenticated = false;
  //   notifyListeners();
  // }

  /// Logout
  Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      final url = Uri.parse('$baseUrl/logout');
      try {
        await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      } catch (_) {
        // ignore network errors on logout
      }
    }
    await _clearAuth();
  }
}
