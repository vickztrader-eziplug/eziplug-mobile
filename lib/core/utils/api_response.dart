/// API Response Handler
/// 
/// Normalizes API responses to work with the new uniform format:
/// { "success": bool, "message": String, "data": dynamic }
/// 
/// This utility ensures backward compatibility with existing code while
/// supporting the new response format from the backend.

class ApiResponse {
  final bool success;
  final String message;
  final dynamic data;
  final Map<String, dynamic>? errors;
  final String? errorCode;
  final Map<String, dynamic> raw;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
    this.errorCode,
    required this.raw,
  });

  /// Creates an ApiResponse from a JSON map (decoded response body)
  /// Handles both new and old API response formats
  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    // New uniform format: { success: bool, message: string, data: any }
    if (json.containsKey('success') && json['success'] is bool) {
      return ApiResponse(
        success: json['success'] as bool,
        message: json['message']?.toString() ?? '',
        data: json['data'],
        errors: json['errors'] as Map<String, dynamic>?,
        errorCode: json['error_code']?.toString(),
        raw: json,
      );
    }

    // Legacy format with 'status' boolean
    if (json.containsKey('status') && json['status'] is bool) {
      // Check for 'results' key (old format)
      final resultData = json['results'] ?? json['data'];
      return ApiResponse(
        success: json['status'] as bool,
        message: json['message']?.toString() ?? '',
        data: resultData,
        errors: json['errors'] as Map<String, dynamic>?,
        errorCode: null,
        raw: json,
      );
    }

    // Legacy format with just 'results'
    if (json.containsKey('results')) {
      return ApiResponse(
        success: true,
        message: json['message']?.toString() ?? '',
        data: json['results'],
        errors: null,
        errorCode: null,
        raw: json,
      );
    }

    // Fallback - treat as success with the whole json as data
    return ApiResponse(
      success: true,
      message: json['message']?.toString() ?? '',
      data: json,
      errors: null,
      errorCode: null,
      raw: json,
    );
  }

  /// Check if response indicates failure
  bool get isError => !success;

  /// Get a specific field from data
  T? getField<T>(String key) {
    if (data is Map<String, dynamic>) {
      return data[key] as T?;
    }
    return null;
  }

  /// Get nested data - handles both new format (data.xxx) and old format (results.xxx)
  dynamic operator [](String key) {
    if (data is Map<String, dynamic>) {
      return data[key];
    }
    return null;
  }

  /// Get token from response (handles multiple formats)
  String? get token {
    if (data is Map<String, dynamic>) {
      return data['token']?.toString();
    }
    return raw['token']?.toString();
  }

  /// Get user from response (handles multiple formats)
  Map<String, dynamic>? get user {
    if (data is Map<String, dynamic>) {
      return data['user'] as Map<String, dynamic>?;
    }
    return raw['user'] as Map<String, dynamic>?;
  }

  /// Convert to standard result map for backward compatibility
  Map<String, dynamic> toResultMap() {
    return {
      'success': success,
      'message': message,
      'data': data,
      if (errors != null) 'errors': errors,
      if (errorCode != null) 'error_code': errorCode,
    };
  }

  @override
  String toString() {
    return 'ApiResponse(success: $success, message: $message, data: $data)';
  }
}

/// Extension on Map to easily convert to ApiResponse
extension ApiResponseExtension on Map<String, dynamic> {
  ApiResponse toApiResponse() => ApiResponse.fromJson(this);
}

/// Helper function to normalize any response format
ApiResponse normalizeResponse(Map<String, dynamic> json) {
  return ApiResponse.fromJson(json);
}

/// Helper to check success from raw json
bool isSuccessResponse(Map<String, dynamic> json) {
  return json['success'] == true || json['status'] == true;
}

/// Helper to get data from raw json (handles both formats)
dynamic getResponseData(Map<String, dynamic> json) {
  return json['data'] ?? json['results'] ?? json;
}

/// Helper to get message from raw json
String getResponseMessage(Map<String, dynamic> json) {
  return json['message']?.toString() ?? '';
}
