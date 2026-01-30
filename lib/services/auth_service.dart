// lib/services/auth_service.dart
import 'dart:convert';
import 'package:cashpoint/core/utils/constants.dart';
import 'package:cashpoint/core/utils/api_response.dart';
import 'package:flutter/material.dart';
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

    // ✅ ADD ONLY THIS LINE - mark as initialized
    _isInitialized = true;
    notifyListeners();
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
      final response = await http.post(
        url,
        headers: {'Accept': 'application/json'},
        body: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(result);

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
        return {
          'success': false,
          'message': 'Email or phone number already exists.',
        };
      } else if (response.statusCode == 422) {
        final result = jsonDecode(response.body);
        final errors = result['errors'] ?? {};
        final message = result['message'] ?? 'Validation failed';

        // Combine field-specific errors
        String combinedErrors = errors.entries
            .map((e) => '${e.key}: ${e.value.join(', ')}')
            .join('\n');

        return {'success': false, 'message': '$message\n$combinedErrors'};
      } else {
        return {
          'success': false,
          'message':
              'Unexpected response (${response.statusCode}): ${response.body}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Server error: $e'};
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
      final response = await http.post(
        url,
        headers: {'Accept': 'application/json'},
        body: data,
      );

      final statusCode = response.statusCode;
      final body = response.body;

      if (statusCode == 200 || statusCode == 201) {
        final result = jsonDecode(body);
        final apiResponse = ApiResponse.fromJson(result);
        print('Login result: $result');
        
        if (apiResponse.success) {
          await _saveAuth(result);
          return {
            'success': true,
            'message': apiResponse.message.isNotEmpty ? apiResponse.message : 'Login successful',
            'user': apiResponse.user,
          };
        } else {
          return {
            'success': false,
            'message': apiResponse.message.isNotEmpty ? apiResponse.message : 'Invalid credentials',
          };
        }
      }
      // Handle Laravel validation errors (422)
      else if (statusCode == 422) {
        final result = jsonDecode(body);
        final errors = result['errors'] ?? {};
        final message = result['message'] ?? 'Validation failed';

        // Combine field-specific errors
        String combinedErrors = errors.entries
            .map((e) => '${e.key}: ${e.value.join(', ')}')
            .join('\n');

        return {'success': false, 'message': '$message\n$combinedErrors'};
      } else if (statusCode == 302) {
        return {
          'success': false,
          'message':
              'Unexpected redirect (302). Confirm your API routes use api.php, not web.php.',
        };
      } else {
        return {
          'success': false,
          'message': 'Unexpected response ($statusCode): $body',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Server error: $e'};
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
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'email': email, 'type': 'verification'}),
      );

      print(
        'Resend OTP Request: ${jsonEncode({'email': email, 'type': 'verification'})}',
      );
      print('Resend OTP Response Status: ${response.statusCode}');
      print('Resend OTP Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(result);

        return {
          'success': apiResponse.success,
          'message': apiResponse.message == 'app.otp_resend'
              ? 'OTP resent successfully to your email'
              : (apiResponse.message.isNotEmpty ? apiResponse.message : 'OTP resent successfully'),
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Session expired. Please register again.',
        };
      } else if (response.statusCode == 422) {
        final result = jsonDecode(response.body);
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to resend OTP',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'message': 'Too many requests. Please try again later.',
        };
      } else {
        final result = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              result['message'] ??
              'Failed to resend OTP (${response.statusCode})',
        };
      }
    } catch (e) {
      print('Resend OTP Error: $e');
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
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);

          // Handle different response structures
          Map<String, dynamic>? user;
          if (result.containsKey('user') && result['user'] is Map) {
            user = Map<String, dynamic>.from(result['user']);
          } else if (result.containsKey('result') && result['result'] is Map) {
            final res = result['result'] as Map;
            if (res.containsKey('user') && res['user'] is Map) {
              user = Map<String, dynamic>.from(res['user']);
            }
          } else if (result is Map && result.containsKey('id')) {
            // If response is the user object itself
            user = Map<String, dynamic>.from(result);
          }

          if (user != null) {
            _user = user;
            _isAuthenticated = true;
            notifyListeners();
          } else {
            await _clearAuth();
          }
        } else {
          await _clearAuth();
        }
      } catch (e) {
        await _clearAuth();
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
