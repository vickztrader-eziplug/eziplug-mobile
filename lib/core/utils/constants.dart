import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class Constants {
  static const String baseUrl =
      // "http://127.0.0.1:8000/api"; // For local testing
      "https://app.eziplug.app/api"; // Production URL.

  // Storage URL (for images, files, etc.)
  static String get storageUrl {
    // Extract base domain from baseUrl and append /storage
    final uri = Uri.parse(baseUrl);
    return '${uri.scheme}://${uri.host}:${uri.port}/storage';
  }

  /// Fix localhost URLs for different platforms
  /// Android emulator uses 10.0.2.2 to reach host machine's localhost
  static String fixLocalUrl(String url) {
    if (url.isEmpty) return url;
    
    // Only fix URLs that point to localhost/127.0.0.1
    if (!url.contains('127.0.0.1') && !url.contains('localhost')) {
      return url;
    }
    
    // For web, localhost works fine
    if (kIsWeb) return url;
    
    // For Android emulator, replace localhost with 10.0.2.2
    try {
      if (Platform.isAndroid) {
        return url
            .replaceAll('127.0.0.1', '10.0.2.2')
            .replaceAll('localhost', '10.0.2.2');
      }
    } catch (e) {
      // Platform not available, return as-is
    }
    
    return url;
  }

  // Reverb (WebSocket) — the "key" is the Reverb app key, public by design
  // (same as a Pusher app key); only the app secret, which never leaves the
  // backend, is sensitive. Must match REVERB_APP_KEY in the backend's .env.
  static const String reverbKey = 'lfmhzpzqyubvxnhplj6v';
  static const int reverbPort = 8080;
  static const bool reverbUseTLS = false; // flip to true once served over wss:// in production

  static String get _apiOrigin {
    final uri = Uri.parse(fixLocalUrl(baseUrl));
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  static String get reverbHost => Uri.parse(fixLocalUrl(baseUrl)).host;

  /// Laravel's broadcasting auth endpoint — lives at the app root, not under
  /// /api (Broadcast::routes() registers it outside the api.php group).
  static String get broadcastAuthUrl => '$_apiOrigin/broadcasting/auth';

  /// Resolve a crypto/coin logo path (relative storage path or full URL)
  /// into a displayable, platform-fixed URL. Returns null if there's no logo.
  static String? resolveLogoUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    final url = path.startsWith('http') ? path : '$storageUrl/$path';
    return fixLocalUrl(url);
  }

  // App Info
  static const String appName = 'Eziplug';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@eziplug.app';
  static const String supportPhone = '+234 806 791 5587';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String pinKey = 'user_pin';

  // Pagination
  static const int defaultPageSize = 20;

  static const sellGiftCardUrl = '$baseUrl/giftcard/sell';
  static const buyGiftCardUrl = '$baseUrl/giftcard/buy';
  static const buyCryptoUrl = '$baseUrl/crypto/buy';
  static const sellCryptoUrl = '$baseUrl/crypto/sell';
  static const uidSellCryptoUrl = '$baseUrl/crypto/uid-sell';
  static const cryptoTradeStatusUrl = '$baseUrl/crypto/trade-status';
  static const cryptoTypes = '$baseUrl/cryptos';

  static const giftCards = '$baseUrl/giftcard';
  static const buyGiftCard = '$baseUrl/giftcard/buy';
  static const sellGiftCard = '$baseUrl/giftcard/sell';
  static const calculateGiftCard = '$baseUrl/giftcard/calculate';
  static const giftCardTransactions = '$baseUrl/giftcard/transactions';

  static const networks = '$baseUrl/networks';
  static const airtime = '$baseUrl/vtu/airtime';
  static const bills = '$baseUrl/vtu/bills';
  static const cables = '$baseUrl/vtu/cables';
  static const cablesPlanById = '$baseUrl/vtu/cable/plan/{id}';
  static const bill = '$baseUrl/vtu/bill';
  static const validate = '$baseUrl/vtu/verify';
  static const cable = '$baseUrl/vtu/cable';
  static const data = '$baseUrl/giftcard/buy';
  static const dataPlans = '$baseUrl/vtu/data/plan/{networkId}';
  static const edupin = '$baseUrl/vtu/edupin';
  static const gituser = '$baseUrl/payout/gift-user';
  static const lockFund = '$baseUrl/payout/lock';
  static const releaseFund = '$baseUrl/payout/release';
  static const lockHistory = '$baseUrl/payout/lock/history';
  static const lockSummary = '$baseUrl/payout/lock/summary';
  static const lockEarnHistory = '$baseUrl/payout/lock/earn-history';
  static const giftcardRates = '$baseUrl/giftcard/rates';
  static const cryptoRates = '$baseUrl/crypto/rates';
  static const airtimeSwapRate = '$baseUrl/vtu/airtime-swap/rate';
  static const airtimeSwapCalculate = '$baseUrl/vtu/airtime-swap/calculate';
  static const airtimeSwapProcess = '$baseUrl/vtu/airtime-swap/swap';
  static const airtimeSwapHistory = '$baseUrl/vtu/airtime-swap/history';
  static const dataHistory = '$baseUrl/vtu/data/history';
  static const airtimeHistory = '$baseUrl/vtu/airtime/history';
  static const billHistory = '$baseUrl/vtu/bill/history';
  static const cableHistory = '$baseUrl/vtu/cable/history';
  static const paymentHistory = '$baseUrl/payment/history';
  static const giftuserHistory = '$baseUrl/payout/giftuser/history';
  static const giftCardHistory = '$baseUrl/giftcard/history';
  static const cryptoHistory = '$baseUrl/crypto/history';
  
  // Leaderboard Endpoints
  static const leaderboard = '$baseUrl/leaderboard';
  static const leaderboardCrypto = '$baseUrl/leaderboard/crypto';
  static const leaderboardGiftcard = '$baseUrl/leaderboard/giftcard';

  // KYC Endpoints
  static const kycStatus = '$baseUrl/kyc/status';
  static const kycTier2 = '$baseUrl/kyc/tier2';
  static const kycTier3 = '$baseUrl/kyc/tier3';
  static const kycHistory = '$baseUrl/kyc/history';

  // Unified Transactions Endpoint (replaces individual history endpoints)
  static const transactions = '$baseUrl/transactions';
  static const transactionDetails = '$baseUrl/transactions'; // Append /{reference}
  static const transactionsSummary = '$baseUrl/transactions/summary';
  static const transactionsCategories = '$baseUrl/transactions/categories';

  // Betting endpoints
  static const String bettingCategories = '$baseUrl/betting/categories';
  static const String bettingEvents = '$baseUrl/betting/events';
  static const String placeBet = '$baseUrl/betting/place-bet';
  static const String betHistory = '$baseUrl/betting/history';
  static const String betStatistics = '$baseUrl/betting/statistics';

  // Image Upload
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxGiftCardImages = 5;

  // Transaction Status
  static const String statusPending = 'pending';
  static const String statusProcessing = 'processing';
  static const String statusCompleted = 'completed';
  static const String statusFailed = 'failed';
  static const String statusCancelled = 'cancelled';

  // Notification Endpoints
  static const String notifications = '$baseUrl/notifications';
  static const String notificationsUnreadCount = '$baseUrl/notifications/unread-count';
  static const String notificationsMarkAllRead = '$baseUrl/notifications/mark-all-read';
  // For single notification: append /{id} to notifications
  // For mark as read: POST to notifications/{id}/mark-read

  // Gift Card Types
  static const String giftCardTypeBuy = 'buy';
  static const String giftCardTypeSell = 'sell';

  // Gift Card Categories
  static const String categoryPhysical = 'Physical';
  static const String categoryEcode = 'E-code';

  static const user = '$baseUrl/user';

  // ==========================================================================
  // P2P Automation Endpoints
  // ==========================================================================
  static const p2pOnboard = '$baseUrl/p2p/onboard';
  static const p2pStatus = '$baseUrl/p2p/status';
  static const p2pDashboard = '$baseUrl/p2p/dashboard';
  static const p2pSettings = '$baseUrl/p2p/settings';
  static const p2pProviders = '$baseUrl/p2p/providers';
  static const p2pExchangeConnect = '$baseUrl/p2p/integrations/exchange/connect';
  static const p2pBankConnect = '$baseUrl/p2p/integrations/bank/connect';
  static const p2pExchangeIntegrations = '$baseUrl/p2p/integrations/exchange';
  static const p2pBankIntegrations = '$baseUrl/p2p/integrations/bank';
  static const p2pBanks = '$baseUrl/p2p/banks';
  static const p2pBanksCached = '$baseUrl/p2p/banks/cached';
  static const p2pBanksVerify = '$baseUrl/p2p/banks/verify';
  static const p2pOrders = '$baseUrl/p2p/orders';
  static const p2pRules = '$baseUrl/p2p/rules';

  // Eziplug's own bank list/verification (Paystack-backed) — used for the
  // beneficiary editor instead of Dohify's own bank/verify, since the actual
  // payout transfer executes through Eziplug's Paystack integration and
  // needs Eziplug's own bank codes, not Dohify's connected provider's.
  static const payoutBankList = '$baseUrl/payout/bank/list';
  static const payoutAccountValidate = '$baseUrl/payout/account/validate';

  static String p2pExchangeTest(String providerId) =>
      '$baseUrl/p2p/integrations/exchange/$providerId/test';
  static String p2pExchangeActive(String providerId) =>
      '$baseUrl/p2p/integrations/exchange/$providerId/active';
  static String p2pBankActive(String providerId) =>
      '$baseUrl/p2p/integrations/bank/$providerId/active';
  static String p2pExchangeDelete(String providerId) =>
      '$baseUrl/p2p/integrations/exchange/$providerId';
  static String p2pBankDelete(String providerId) =>
      '$baseUrl/p2p/integrations/bank/$providerId';

  static String p2pOrderDetail(String id) => '$baseUrl/p2p/orders/$id';
  static String p2pOrderHistory(String id) => '$baseUrl/p2p/orders/$id/history';
  static String p2pOrderEvents(String id) => '$baseUrl/p2p/orders/$id/events';
  static String p2pOrderManualApproval(String id) =>
      '$baseUrl/p2p/orders/$id/manual-approval';
  static String p2pOrderMarkPay(String id) => '$baseUrl/p2p/orders/$id/mark-pay';
  static String p2pOrderReceipt(String id) => '$baseUrl/p2p/orders/$id/receipt';
  static String p2pOrderPayNow(String id) => '$baseUrl/p2p/orders/$id/pay-now';
  static String p2pOrderApprovePayin(String id) =>
      '$baseUrl/p2p/orders/$id/approve-payin';
  static String p2pOrderPayUnpaidCompleted(String id) =>
      '$baseUrl/p2p/orders/$id/pay-unpaid-completed';
  static String p2pOrderMarkDone(String id) => '$baseUrl/p2p/orders/$id/mark-done';
  static String p2pOrderRetry(String id) => '$baseUrl/p2p/orders/$id/retry';
  static String p2pOrderCancel(String id) => '$baseUrl/p2p/orders/$id/cancel';
  static String p2pOrderBeneficiary(String id) =>
      '$baseUrl/p2p/orders/$id/beneficiary';

  static String p2pRuleDetail(String id) => '$baseUrl/p2p/rules/$id';

  /// [type] must be literally 'blacklist' or 'whitelist'
  static String p2pList(String type) => '$baseUrl/p2p/lists/$type';
  static String p2pListEntryDelete(String type, String entryId) =>
      '$baseUrl/p2p/lists/$type/$entryId';
}
