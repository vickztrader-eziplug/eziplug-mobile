import 'package:flutter/material.dart';

class Constants {
  static const String baseUrl =
      // "http://127.0.0.1:8000/api"; // For local testing
      "https://app.eziplug.app/api"; // Production URL

  // App Info
  static const String appName = 'Eziplug';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@eziplug.ng';
  static const String supportPhone = '+234 806 791 5587';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String pinKey = 'user_pin';

  // Pagination
  static const int defaultPageSize = 20;

  static const String paystackPublicKey = "pk_live_e11f08bf1689bc8ea11a550bcbfd6d4e68ee2b8b";
  static const String paystackSecreteKey = "sk_live_5873ce22b9e6f34bad22bf5bf330d6e7133a2cda";
  static const sellGiftCardUrl = '$baseUrl/giftcard/sell';
  static const buyGiftCardUrl = '$baseUrl/giftcard/buy';
  static const buyCryptoUrl = '$baseUrl/wallet/withdraw';

  static const giftCards = '$baseUrl/giftcard';
  static const buyGiftCard = '$baseUrl/giftcard/buy';
  static const sellGiftCard = '$baseUrl/giftcard/sell';
  static const calculateGiftCard = '$baseUrl/giftcard/calculate';
  static const giftCardTransactions = '$baseUrl/giftcard/transactions';

  static const createWalletUrl = '$baseUrl/wallet/create';
  static const depositCryptoUrl = '$baseUrl/giftcard/buy';
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
  static const cryotoHistory = '$baseUrl/crypto/history';
  
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

  // Gift Card Types
  static const String giftCardTypeBuy = 'buy';
  static const String giftCardTypeSell = 'sell';

  // Gift Card Categories
  static const String categoryPhysical = 'Physical';
  static const String categoryEcode = 'E-code';

  static const user = '$baseUrl/user';
}
