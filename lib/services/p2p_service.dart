// lib/services/p2p_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/utils/constants.dart';
import '../models/p2p/p2p.dart';
import 'auth_service.dart';

/// Wraps every HTTP call for the P2P Automation feature.
///
/// Follows the same lightweight pattern as [BettingService]/`TransactionService`:
/// no DI container, just a plain class that resolves the bearer token itself
/// (via a passed-in [AuthService] if one is supplied, otherwise a fresh
/// [AuthService] instance backed by secure storage) and returns a uniform
/// `{success, message, data}` map (plus `meta` for paginated endpoints) that
/// screens can pattern-match on, mirroring the backend's own response envelope.
class P2pService {
  final AuthService? _authService;
  static const Duration _timeout = Duration(seconds: 30);

  P2pService({AuthService? authService}) : _authService = authService;

  Future<String?> _getToken() async {
    final service = _authService ?? AuthService();
    return service.getToken();
  }

  Map<String, String> _headers(String? token, {bool withContentType = false}) {
    return {
      'Accept': 'application/json',
      if (withContentType) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Normalizes a raw HTTP response against the backend's uniform envelope:
  /// `{ "success": bool, "message": string, "data": <payload or null> }`.
  Map<String, dynamic> _parse(http.Response response) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } catch (_) {
      body = <String, dynamic>{};
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    final success = body['success'] == true || (ok && !body.containsKey('success'));

    String message = body['message']?.toString() ?? '';
    if (message.isEmpty) {
      message = success
          ? 'Success'
          : 'Request failed (${response.statusCode})';
    }

    final result = <String, dynamic>{
      'success': success && ok,
      'message': message,
      'data': body['data'],
      'statusCode': response.statusCode,
    };

    if (body['meta'] != null) {
      result['meta'] = body['meta'];
    }

    return result;
  }

  Map<String, dynamic> _exceptionResult(Object e) {
    if (e is TimeoutException) {
      return {'success': false, 'message': 'Request timed out. Please try again.'};
    }
    return {'success': false, 'message': 'Network error: ${e.toString()}'};
  }

  Future<Map<String, dynamic>> _get(Uri url) async {
    try {
      final token = await _getToken();
      final response =
          await http.get(url, headers: _headers(token)).timeout(_timeout);
      return _parse(response);
    } catch (e) {
      return _exceptionResult(e);
    }
  }

  Future<Map<String, dynamic>> _post(Uri url, [Map<String, dynamic>? body]) async {
    try {
      final token = await _getToken();
      final response = await http
          .post(
            url,
            headers: _headers(token, withContentType: true),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _parse(response);
    } catch (e) {
      return _exceptionResult(e);
    }
  }

  Future<Map<String, dynamic>> _put(Uri url, [Map<String, dynamic>? body]) async {
    try {
      final token = await _getToken();
      final response = await http
          .put(
            url,
            headers: _headers(token, withContentType: true),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _parse(response);
    } catch (e) {
      return _exceptionResult(e);
    }
  }

  Future<Map<String, dynamic>> _delete(Uri url) async {
    try {
      final token = await _getToken();
      final response =
          await http.delete(url, headers: _headers(token)).timeout(_timeout);
      return _parse(response);
    } catch (e) {
      return _exceptionResult(e);
    }
  }

  Future<Map<String, dynamic>> _multipart(
    String method,
    Uri url, {
    Map<String, String>? fields,
    File? file,
    String fileField = 'receipt',
  }) async {
    try {
      final token = await _getToken();
      final request = http.MultipartRequest(method, url);
      request.headers.addAll(_headers(token));
      if (fields != null) request.fields.addAll(fields);
      if (file != null) {
        request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
      }
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return _parse(response);
    } catch (e) {
      return _exceptionResult(e);
    }
  }

  // ==========================================================================
  // Onboarding & status
  // ==========================================================================

  Future<Map<String, dynamic>> onboard() async {
    final result = await _post(Uri.parse(Constants.p2pOnboard));
    return result;
  }

  Future<Map<String, dynamic>> getStatus() async {
    final result = await _get(Uri.parse(Constants.p2pStatus));
    if (result['success'] == true && result['data'] is Map) {
      result['status'] =
          P2pMerchantStatus.fromJson(Map<String, dynamic>.from(result['data']));
    }
    return result;
  }

  // ==========================================================================
  // Dashboard
  // ==========================================================================

  Future<Map<String, dynamic>> getDashboard({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String();
    }
    final uri = Uri.parse(Constants.p2pDashboard).replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final result = await _get(uri);
    if (result['success'] == true && result['data'] is Map) {
      result['stats'] =
          P2pDashboardStats.fromJson(Map<String, dynamic>.from(result['data']));
    }
    return result;
  }

  // ==========================================================================
  // Settings & fees
  // ==========================================================================

  Future<Map<String, dynamic>> getSettings() async {
    return _get(Uri.parse(Constants.p2pSettings));
  }

  Future<Map<String, dynamic>> updateSettings({
    bool? autoPayoutsEnabled,
    bool? bypassNameCheck,
    String? payoutMode,
    bool? triggerPendingPayouts,
    String? releaseMessage,
  }) async {
    final body = <String, dynamic>{
      if (autoPayoutsEnabled != null) 'auto_payouts_enabled': autoPayoutsEnabled,
      if (bypassNameCheck != null) 'bypass_name_check': bypassNameCheck,
      if (payoutMode != null) 'payout_mode': payoutMode,
      if (triggerPendingPayouts != null)
        'trigger_pending_payouts': triggerPendingPayouts,
      if (releaseMessage != null) 'release_message': releaseMessage,
    };
    return _put(Uri.parse(Constants.p2pSettings), body);
  }

  // ==========================================================================
  // Providers & integrations
  // ==========================================================================

  Future<Map<String, dynamic>> getProviders({required String category}) async {
    final uri = Uri.parse(Constants.p2pProviders)
        .replace(queryParameters: {'category': category});
    final result = await _get(uri);
    if (result['success'] == true && result['data'] is List) {
      result['providers'] = (result['data'] as List)
          .whereType<Map>()
          .map((e) => P2pProvider.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return result;
  }

  Future<Map<String, dynamic>> connectExchange({
    required String providerId,
    required Map<String, dynamic> credentials,
  }) async {
    return _post(Uri.parse(Constants.p2pExchangeConnect), {
      'provider_id': providerId,
      'credentials': credentials,
    });
  }

  Future<Map<String, dynamic>> connectBank({
    required String providerId,
    required Map<String, dynamic> credentials,
  }) async {
    return _post(Uri.parse(Constants.p2pBankConnect), {
      'provider_id': providerId,
      'credentials': credentials,
    });
  }

  Future<Map<String, dynamic>> getExchangeIntegrations() async {
    final result = await _get(Uri.parse(Constants.p2pExchangeIntegrations));
    if (result['success'] == true && result['data'] is List) {
      result['providers'] = (result['data'] as List)
          .whereType<Map>()
          .map((e) => P2pProvider.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return result;
  }

  Future<Map<String, dynamic>> getBankIntegrations() async {
    final result = await _get(Uri.parse(Constants.p2pBankIntegrations));
    if (result['success'] == true && result['data'] is List) {
      result['providers'] = (result['data'] as List)
          .whereType<Map>()
          .map((e) => P2pProvider.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return result;
  }

  Future<Map<String, dynamic>> testExchangeConnection(String providerId) async {
    return _post(Uri.parse(Constants.p2pExchangeTest(providerId)));
  }

  Future<Map<String, dynamic>> setExchangeActive(
      String providerId, bool isActive) async {
    return _put(
      Uri.parse(Constants.p2pExchangeActive(providerId)),
      {'is_active': isActive},
    );
  }

  Future<Map<String, dynamic>> setBankActive(
      String providerId, bool isActive) async {
    return _put(
      Uri.parse(Constants.p2pBankActive(providerId)),
      {'is_active': isActive},
    );
  }

  Future<Map<String, dynamic>> deleteExchangeIntegration(String providerId) async {
    return _delete(Uri.parse(Constants.p2pExchangeDelete(providerId)));
  }

  Future<Map<String, dynamic>> deleteBankIntegration(String providerId) async {
    return _delete(Uri.parse(Constants.p2pBankDelete(providerId)));
  }

  // ==========================================================================
  // Banks
  // ==========================================================================

  Future<Map<String, dynamic>> getBanks() async {
    return _get(Uri.parse(Constants.p2pBanks));
  }

  Future<Map<String, dynamic>> getCachedBanks() async {
    return _get(Uri.parse(Constants.p2pBanksCached));
  }

  Future<Map<String, dynamic>> verifyBankAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    final uri = Uri.parse(Constants.p2pBanksVerify).replace(queryParameters: {
      'bank_code': bankCode,
      'account_number': accountNumber,
    });
    return _get(uri);
  }

  /// Eziplug's own bank list (Paystack-backed) — `data` is a flat
  /// `[{id, name, code, slug, type}, ...]` array.
  Future<Map<String, dynamic>> getEziplugBanks() async {
    return _get(Uri.parse(Constants.payoutBankList));
  }

  /// Eziplug's own account-name resolution (Paystack-backed), matching the
  /// bank codes getEziplugBanks() returns — the same lookup the real payout
  /// transfer relies on, unlike Dohify's own /bank/verify which resolves
  /// against Dohify's connected provider's (different) bank codes.
  Future<Map<String, dynamic>> validateEziplugBankAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    return _post(Uri.parse(Constants.payoutAccountValidate), {
      'bank_code': bankCode,
      'account_number': accountNumber,
    });
  }

  // ==========================================================================
  // Orders
  // ==========================================================================

  Future<Map<String, dynamic>> getOrders({
    String? status,
    String? excludeStatus,
    String? tradeType,
    String? providerId,
    int? page,
    int? perPage,
  }) async {
    final queryParams = <String, String>{
      if (status != null) 'status': status,
      if (excludeStatus != null) 'exclude_status': excludeStatus,
      if (tradeType != null) 'trade_type': tradeType,
      if (providerId != null) 'provider_id': providerId,
      if (page != null) 'page': page.toString(),
      if (perPage != null) 'per_page': perPage.toString(),
    };
    final uri = Uri.parse(Constants.p2pOrders).replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final result = await _get(uri);
    if (result['success'] == true) {
      // The backend wraps paginated lists as `data: {data: [...], meta: {...}}`
      // (rather than a bare array) because it also needs to carry pagination
      // meta alongside the list — handle both that shape and a bare list
      // defensively.
      final rawData = result['data'];
      List<dynamic>? rawOrders;
      if (rawData is List) {
        rawOrders = rawData;
      } else if (rawData is Map) {
        final nested = rawData['data'];
        if (nested is List) rawOrders = nested;
        result['meta'] ??= rawData['meta'] is Map
            ? (rawData['meta'] as Map)['pagination'] ?? rawData['meta']
            : rawData['meta'];
      }
      if (rawOrders != null) {
        result['orders'] = rawOrders
            .whereType<Map>()
            .map((e) => P2pOrder.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> getOrderDetail(String id) async {
    final result = await _get(Uri.parse(Constants.p2pOrderDetail(id)));
    if (result['success'] == true && result['data'] is Map) {
      result['order'] =
          P2pOrder.fromJson(Map<String, dynamic>.from(result['data']));
    }
    return result;
  }

  Future<Map<String, dynamic>> getOrderHistory(String id) async {
    final result = await _get(Uri.parse(Constants.p2pOrderHistory(id)));
    if (result['success'] == true && result['data'] is List) {
      result['history'] = (result['data'] as List)
          .whereType<Map>()
          .map((e) => P2pOrderHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return result;
  }

  Future<Map<String, dynamic>> getOrderEvents(String id) async {
    final result = await _get(Uri.parse(Constants.p2pOrderEvents(id)));
    if (result['success'] == true && result['data'] is List) {
      result['events'] = (result['data'] as List)
          .whereType<Map>()
          .map((e) => P2pOrderEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return result;
  }

  Future<Map<String, dynamic>> manualApproval(
    String id, {
    required String action,
    String? reason,
  }) async {
    return _post(Uri.parse(Constants.p2pOrderManualApproval(id)), {
      'action': action,
      if (reason != null) 'reason': reason,
    });
  }

  /// Confirms a self-managed order was paid. The backend handles the actual
  /// payout and receipt automatically when auto-payouts are on, so no
  /// attachment is collected here — [receipt] only exists for the (rare)
  /// manual fallback where auto-payout is off and a human already has proof.
  Future<Map<String, dynamic>> markPay(String id, {File? receipt}) async {
    return _multipart('POST', Uri.parse(Constants.p2pOrderMarkPay(id)), file: receipt);
  }

  /// Executes the real payout (bank resolve, transfer, receipt, then tells
  /// Dohify) for a self-managed order right now, regardless of whether the
  /// merchant's auto-payouts toggle is on.
  Future<Map<String, dynamic>> payNow(String id) async {
    return _post(Uri.parse(Constants.p2pOrderPayNow(id)));
  }

  Future<Map<String, dynamic>> approvePayin(String id) async {
    return _post(Uri.parse(Constants.p2pOrderApprovePayin(id)));
  }

  Future<Map<String, dynamic>> payUnpaidCompleted(String id) async {
    return _post(Uri.parse(Constants.p2pOrderPayUnpaidCompleted(id)));
  }

  Future<Map<String, dynamic>> markDone(String id) async {
    return _post(Uri.parse(Constants.p2pOrderMarkDone(id)));
  }

  Future<Map<String, dynamic>> retryOrder(String id) async {
    return _post(Uri.parse(Constants.p2pOrderRetry(id)));
  }

  Future<Map<String, dynamic>> cancelOrder(String id) async {
    return _post(Uri.parse(Constants.p2pOrderCancel(id)));
  }

  Future<Map<String, dynamic>> updateBeneficiary(
    String id, {
    required String beneficiaryName,
    required String beneficiaryBank,
    required String beneficiaryAccount,
    String? beneficiaryRealName,
    bool? nameMatched,
  }) async {
    return _put(Uri.parse(Constants.p2pOrderBeneficiary(id)), {
      'beneficiary_name': beneficiaryName,
      'beneficiary_bank': beneficiaryBank,
      'beneficiary_account': beneficiaryAccount,
      if (beneficiaryRealName != null) 'beneficiary_real_name': beneficiaryRealName,
      if (nameMatched != null) 'name_matched': nameMatched,
    });
  }

  // ==========================================================================
  // Rules
  // ==========================================================================

  Future<Map<String, dynamic>> getRules({bool? activeOnly}) async {
    final uri = Uri.parse(Constants.p2pRules).replace(
      queryParameters:
          activeOnly != null ? {'active_only': activeOnly.toString()} : null,
    );
    final result = await _get(uri);
    if (result['success'] == true && result['data'] is List) {
      result['rules'] = (result['data'] as List)
          .whereType<Map>()
          .map((e) => P2pRule.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return result;
  }

  Future<Map<String, dynamic>> createRule({
    required String name,
    required String type,
    required Map<String, dynamic> conditions,
    required String action,
    required int priority,
    required bool isActive,
  }) async {
    return _post(Uri.parse(Constants.p2pRules), {
      'name': name,
      'type': type,
      'conditions': conditions,
      'action': action,
      'priority': priority,
      'is_active': isActive,
    });
  }

  Future<Map<String, dynamic>> getRule(String id) async {
    final result = await _get(Uri.parse(Constants.p2pRuleDetail(id)));
    if (result['success'] == true && result['data'] is Map) {
      result['rule'] = P2pRule.fromJson(Map<String, dynamic>.from(result['data']));
    }
    return result;
  }

  Future<Map<String, dynamic>> updateRule(
    String id, {
    String? name,
    String? type,
    Map<String, dynamic>? conditions,
    String? action,
    int? priority,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (conditions != null) 'conditions': conditions,
      if (action != null) 'action': action,
      if (priority != null) 'priority': priority,
      if (isActive != null) 'is_active': isActive,
    };
    return _put(Uri.parse(Constants.p2pRuleDetail(id)), body);
  }

  Future<Map<String, dynamic>> deleteRule(String id) async {
    return _delete(Uri.parse(Constants.p2pRuleDetail(id)));
  }

  // ==========================================================================
  // Blacklist / whitelist
  // ==========================================================================

  /// [listType] must be literally 'blacklist' or 'whitelist'.
  Future<Map<String, dynamic>> getLists(String listType, {String? entryType}) async {
    final uri = Uri.parse(Constants.p2pList(listType)).replace(
      queryParameters: entryType != null ? {'entry_type': entryType} : null,
    );
    final result = await _get(uri);
    if (result['success'] == true && result['data'] is List) {
      result['entries'] = (result['data'] as List)
          .whereType<Map>()
          .map((e) => P2pListEntry.fromJson(
                Map<String, dynamic>.from(e),
                listType: listType,
              ))
          .toList();
    }
    return result;
  }

  /// [listType] must be literally 'blacklist' or 'whitelist'.
  /// [entryType] is one of [P2pListEntry.allEntryTypes].
  Future<Map<String, dynamic>> addListEntry(
    String listType, {
    required String entryType,
    required String value,
    String? reason,
  }) async {
    return _post(Uri.parse(Constants.p2pList(listType)), {
      'type': entryType,
      'value': value,
      if (reason != null) 'reason': reason,
    });
  }

  Future<Map<String, dynamic>> deleteListEntry(String listType, String entryId) async {
    return _delete(Uri.parse(Constants.p2pListEntryDelete(listType, entryId)));
  }
}
