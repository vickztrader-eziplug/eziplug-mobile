/// A blacklist/whitelist entry from the /p2p/lists/{type} endpoints.
///
/// [listType] ("blacklist" or "whitelist") is the path segment used to fetch
/// this entry — the backend doesn't necessarily echo it back per-entry, so
/// the service stamps it on after parsing.
class P2pListEntry {
  static const entryTypeBankAccount = 'BANK_ACCOUNT';
  static const entryTypeUserId = 'USER_ID';
  static const entryTypeBankCode = 'BANK_CODE';

  static const List<String> allEntryTypes = [
    entryTypeBankAccount,
    entryTypeUserId,
    entryTypeBankCode,
  ];

  final String id;
  final String entryType;
  final String value;
  final String? reason;
  final String listType;

  const P2pListEntry({
    required this.id,
    required this.entryType,
    required this.value,
    this.reason,
    required this.listType,
  });

  factory P2pListEntry.fromJson(Map<String, dynamic> json, {String listType = ''}) {
    return P2pListEntry(
      id: json['id']?.toString() ?? '',
      entryType: json['type']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      reason: json['reason']?.toString(),
      listType: json['list_type']?.toString() ?? listType,
    );
  }
}
