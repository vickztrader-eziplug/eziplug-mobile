/// Lightweight summary of a connected exchange/bank provider as returned
/// inline in the dashboard payload (`connected_providers`).
class P2pConnectedProviderSummary {
  final String providerId;
  final String name;
  final String category;
  final bool isConnected;
  final bool isActive;

  const P2pConnectedProviderSummary({
    required this.providerId,
    required this.name,
    required this.category,
    required this.isConnected,
    required this.isActive,
  });

  factory P2pConnectedProviderSummary.fromJson(Map<String, dynamic> json) {
    return P2pConnectedProviderSummary(
      providerId: json['provider_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      isConnected: json['is_connected'] == true,
      isActive: json['is_active'] == true,
    );
  }
}

/// GET /p2p/dashboard response payload.
class P2pDashboardStats {
  final int totalTrades;
  final int completedTrades;
  final int pendingTrades;
  final int failedTrades;
  final double successRate;
  final double averagePayoutTimeSeconds;
  final double? bankBalance;
  final String? bankError;
  final double tradingVolume;
  final double revenue;
  final double feeBalance;
  final int manualReviewTrades;
  final double manualReviewVolume;
  final double eziplugWalletBalance;
  final List<P2pConnectedProviderSummary> connectedProviders;

  const P2pDashboardStats({
    required this.totalTrades,
    required this.completedTrades,
    required this.pendingTrades,
    required this.failedTrades,
    required this.successRate,
    required this.averagePayoutTimeSeconds,
    this.bankBalance,
    this.bankError,
    required this.tradingVolume,
    required this.revenue,
    required this.feeBalance,
    required this.manualReviewTrades,
    required this.manualReviewVolume,
    this.eziplugWalletBalance = 0,
    this.connectedProviders = const [],
  });

  static int _int(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  static double _double(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0.0;

  factory P2pDashboardStats.fromJson(Map<String, dynamic> json) {
    final providersRaw = json['connected_providers'];
    final providers = <P2pConnectedProviderSummary>[];
    if (providersRaw is List) {
      for (final p in providersRaw) {
        if (p is Map<String, dynamic>) {
          providers.add(P2pConnectedProviderSummary.fromJson(p));
        } else if (p is Map) {
          providers.add(P2pConnectedProviderSummary.fromJson(
            Map<String, dynamic>.from(p),
          ));
        }
      }
    }

    return P2pDashboardStats(
      totalTrades: _int(json['total_trades']),
      completedTrades: _int(json['completed_trades']),
      pendingTrades: _int(json['pending_trades']),
      failedTrades: _int(json['failed_trades']),
      successRate: _double(json['success_rate']),
      averagePayoutTimeSeconds: _double(json['average_payout_time_seconds']),
      bankBalance: json['bank_balance'] != null ? _double(json['bank_balance']) : null,
      bankError: json['bank_error']?.toString(),
      tradingVolume: _double(json['trading_volume']),
      revenue: _double(json['revenue']),
      feeBalance: _double(json['fee_balance']),
      manualReviewTrades: _int(json['manual_review_trades']),
      manualReviewVolume: _double(json['manual_review_volume']),
      eziplugWalletBalance: _double(json['eziplug_wallet_balance']),
      connectedProviders: providers,
    );
  }
}
