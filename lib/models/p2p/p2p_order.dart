/// A merchant's P2P trade order and its automated settlement state, from
/// GET /p2p/orders and GET /p2p/orders/{id}.
class P2pOrder {
  static const statusPending = 'PENDING';
  static const statusProcessing = 'PROCESSING';
  static const statusManualReview = 'MANUAL_REVIEW';
  static const statusCompleted = 'COMPLETED';
  static const statusUnpaidCompleted = 'UNPAID_COMPLETED';
  static const statusCancelled = 'CANCELLED';
  static const statusFailed = 'FAILED';
  static const statusProcessedExternally = 'PROCESSED_EXTERNALLY';
  static const statusPaidAwaitingReceipt = 'PAID_AWAITING_RECEIPT';

  static const tradeTypeBuy = 'BUY';
  static const tradeTypeSell = 'SELL';

  /// Shared with the orders list screen and the P2P home screen's pending
  /// count badge, so both always mean exactly the same thing by "active".
  static const activeStatuses =
      'PENDING,PROCESSING,MANUAL_REVIEW,PAID_AWAITING_RECEIPT,UNPAID_COMPLETED';
  static const historyStatuses = 'COMPLETED,CANCELLED,FAILED,PROCESSED_EXTERNALLY';

  final String id;
  final String providerOrderId;
  final double amount;
  final double price;
  final double qty;
  final String fiatCurrency;
  final String assetCurrency;
  final String? beneficiaryName;
  final String? beneficiaryRealName;
  final String? beneficiaryAccount;
  final String? beneficiaryBank;
  final String status;
  final String? reviewReason;
  final String payoutMode;
  final String tradeType;
  final String? errorMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? exchangeProviderName;
  final String? payoutProviderName;
  final String? counterpartyAvgTime;
  final int? counterpartyBadReviews;
  final double? feeCollected;
  final String? payoutReference;
  final String? transactionReference;
  final Map<String, dynamic> raw;

  const P2pOrder({
    required this.id,
    required this.providerOrderId,
    required this.amount,
    required this.price,
    required this.qty,
    required this.fiatCurrency,
    required this.assetCurrency,
    this.beneficiaryName,
    this.beneficiaryRealName,
    this.beneficiaryAccount,
    this.beneficiaryBank,
    required this.status,
    this.reviewReason,
    required this.payoutMode,
    required this.tradeType,
    this.errorMessage,
    this.createdAt,
    this.updatedAt,
    this.exchangeProviderName,
    this.payoutProviderName,
    this.counterpartyAvgTime,
    this.counterpartyBadReviews,
    this.feeCollected,
    this.payoutReference,
    this.transactionReference,
    this.raw = const {},
  });

  bool get isBuy => tradeType == tradeTypeBuy;
  bool get isSell => tradeType == tradeTypeSell;
  bool get isDohifyManaged => payoutMode == 'DOHIFY_MANAGED';
  bool get isSelfManaged => payoutMode == 'SELF_MANAGED';

  static double? _nullableDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());
  static double _double(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

  factory P2pOrder.fromJson(Map<String, dynamic> json) {
    return P2pOrder(
      id: json['id']?.toString() ?? '',
      providerOrderId: json['provider_order_id']?.toString() ?? '',
      amount: _double(json['amount']),
      price: _double(json['price']),
      qty: _double(json['qty']),
      fiatCurrency: json['fiat_currency']?.toString() ?? '',
      assetCurrency: json['asset_currency']?.toString() ?? '',
      beneficiaryName: json['beneficiary_name']?.toString(),
      beneficiaryRealName: json['beneficiary_real_name']?.toString(),
      beneficiaryAccount: json['beneficiary_account']?.toString(),
      beneficiaryBank: json['beneficiary_bank']?.toString(),
      status: json['status']?.toString() ?? '',
      reviewReason: json['review_reason']?.toString(),
      payoutMode: json['payout_mode']?.toString() ?? '',
      tradeType: json['trade_type']?.toString() ?? '',
      errorMessage: json['error_message']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      exchangeProviderName: json['exchange_provider_name']?.toString(),
      payoutProviderName: json['payout_provider_name']?.toString(),
      // Dohify sends this pre-formatted (e.g. "15m"), not a raw number of
      // seconds — parsing it as a double silently failed and dropped it.
      counterpartyAvgTime: json['counterparty_avg_time']?.toString(),
      counterpartyBadReviews: json['counterparty_bad_reviews'] != null
          ? int.tryParse(json['counterparty_bad_reviews'].toString())
          : null,
      feeCollected: _nullableDouble(json['fee_collected']),
      payoutReference: json['payout_reference']?.toString(),
      transactionReference: json['transaction_reference']?.toString(),
      raw: json,
    );
  }
}

/// One row from GET /p2p/orders/{id}/history.
class P2pOrderHistoryEntry {
  final String id;
  final String? statusFrom;
  final String statusTo;
  final String? reason;
  final DateTime? createdAt;

  const P2pOrderHistoryEntry({
    required this.id,
    this.statusFrom,
    required this.statusTo,
    this.reason,
    this.createdAt,
  });

  factory P2pOrderHistoryEntry.fromJson(Map<String, dynamic> json) {
    return P2pOrderHistoryEntry(
      id: json['id']?.toString() ?? '',
      statusFrom: json['status_from']?.toString(),
      statusTo: json['status_to']?.toString() ?? '',
      reason: json['reason']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

/// One row from GET /p2p/orders/{id}/events.
class P2pOrderEvent {
  final String id;
  final String eventType;
  final String? description;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  const P2pOrderEvent({
    required this.id,
    required this.eventType,
    this.description,
    this.metadata,
    this.createdAt,
  });

  factory P2pOrderEvent.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? metadata;
    final rawMeta = json['metadata'];
    if (rawMeta is Map<String, dynamic>) {
      metadata = rawMeta;
    } else if (rawMeta is Map) {
      metadata = Map<String, dynamic>.from(rawMeta);
    }
    return P2pOrderEvent(
      id: json['id']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? '',
      description: json['description']?.toString(),
      metadata: metadata,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

/// A single row in the combined history+events timeline shown on the order
/// detail screen, sorted by [timestamp].
class P2pTimelineEntry {
  final DateTime timestamp;
  final String title;
  final String? subtitle;
  final bool isEvent;

  const P2pTimelineEntry({
    required this.timestamp,
    required this.title,
    this.subtitle,
    required this.isEvent,
  });

  factory P2pTimelineEntry.fromHistory(P2pOrderHistoryEntry h) {
    final from = h.statusFrom;
    final title = from != null && from.isNotEmpty
        ? '$from → ${h.statusTo}'
        : h.statusTo;
    return P2pTimelineEntry(
      timestamp: h.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      title: title,
      subtitle: h.reason,
      isEvent: false,
    );
  }

  factory P2pTimelineEntry.fromEvent(P2pOrderEvent e) {
    return P2pTimelineEntry(
      timestamp: e.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      title: e.eventType,
      subtitle: e.description,
      isEvent: true,
    );
  }
}
