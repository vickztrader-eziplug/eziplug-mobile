/// Merchant P2P onboarding/status snapshot, from GET /p2p/status.
class P2pMerchantStatus {
  static const String payoutModeDohifyManaged = 'DOHIFY_MANAGED';
  static const String payoutModeSelfManaged = 'SELF_MANAGED';

  final bool onboarded;
  final String payoutMode;
  final bool autoPayoutsEnabled;
  final bool bypassNameCheck;
  final String? name;
  final String? email;
  final String? phone;

  /// Full raw payload, kept around so any extra passthrough profile fields
  /// the backend adds later can still be read without a model change.
  final Map<String, dynamic> raw;

  const P2pMerchantStatus({
    required this.onboarded,
    required this.payoutMode,
    required this.autoPayoutsEnabled,
    required this.bypassNameCheck,
    this.name,
    this.email,
    this.phone,
    this.raw = const {},
  });

  bool get isDohifyManaged => payoutMode == payoutModeDohifyManaged;
  bool get isSelfManaged => payoutMode == payoutModeSelfManaged;

  factory P2pMerchantStatus.fromJson(Map<String, dynamic> json) {
    // GET /p2p/status nests everything under `merchant` (our local DB
    // mirror) and `profile` (live data fetched fresh from Dohify) rather
    // than putting these fields at the top level. Prefer `profile` since
    // it's the live source of truth; fall back to `merchant`, then to the
    // top level for robustness against a future flatter shape.
    final merchant = json['merchant'] is Map
        ? Map<String, dynamic>.from(json['merchant'] as Map)
        : const <String, dynamic>{};
    final profile = json['profile'] is Map
        ? Map<String, dynamic>.from(json['profile'] as Map)
        : const <String, dynamic>{};

    dynamic pick(String key) => profile[key] ?? merchant[key] ?? json[key];

    return P2pMerchantStatus(
      onboarded: json['onboarded'] == true,
      payoutMode: pick('payout_mode')?.toString() ?? payoutModeSelfManaged,
      autoPayoutsEnabled: pick('auto_payouts_enabled') == true,
      bypassNameCheck: pick('bypass_name_check') == true,
      name: pick('name')?.toString(),
      email: pick('email')?.toString(),
      phone: pick('phone')?.toString(),
      raw: json,
    );
  }
}
