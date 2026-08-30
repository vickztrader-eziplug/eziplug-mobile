/// A single field of a provider's dynamic credential form.
///
/// Drives a purely dynamic "connect" form — never hardcode provider-specific
/// field names, always render from this schema.
class P2pAuthSchemaField {
  final String name;
  final String label;
  final String type; // e.g. "text", "select", "password"
  final bool required;
  final List<String>? options;

  const P2pAuthSchemaField({
    required this.name,
    required this.label,
    required this.type,
    required this.required,
    this.options,
  });

  factory P2pAuthSchemaField.fromJson(Map<String, dynamic> json) {
    List<String>? options;
    final rawOptions = json['options'];
    if (rawOptions is List) {
      options = rawOptions.map((e) => e.toString()).toList();
    }
    return P2pAuthSchemaField(
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString() ?? json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      required: json['required'] == true,
      options: options,
    );
  }
}

/// An exchange or bank payout provider from GET /p2p/providers (and the
/// connection-listing endpoints, which share this shape plus a few extra
/// connection-specific fields we surface defensively via [raw]).
class P2pProvider {
  final String id;
  final String name;
  final String category; // "exchange" | "bank"
  final bool isConnected;
  final bool isActive;
  final bool isProviderActive;
  final String? connectInstruction;
  final String? logoUrl;
  final List<P2pAuthSchemaField> authSchema;
  final double? balance;
  final String? balanceError;
  final String? virtualAccountNumber;
  final String? virtualAccountName;
  final String? virtualAccountBankName;
  final Map<String, dynamic> raw;

  const P2pProvider({
    required this.id,
    required this.name,
    required this.category,
    required this.isConnected,
    required this.isActive,
    required this.isProviderActive,
    this.connectInstruction,
    this.logoUrl,
    this.authSchema = const [],
    this.balance,
    this.balanceError,
    this.virtualAccountNumber,
    this.virtualAccountName,
    this.virtualAccountBankName,
    this.raw = const {},
  });

  bool get isExchange => category == 'exchange';
  bool get isBank => category == 'bank';

  factory P2pProvider.fromJson(Map<String, dynamic> json) {
    final schemaRaw = json['auth_schema'];
    final schema = <P2pAuthSchemaField>[];
    if (schemaRaw is List) {
      for (final f in schemaRaw) {
        if (f is Map<String, dynamic>) {
          schema.add(P2pAuthSchemaField.fromJson(f));
        } else if (f is Map) {
          schema.add(P2pAuthSchemaField.fromJson(Map<String, dynamic>.from(f)));
        }
      }
    }

    return P2pProvider(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      isConnected: json['is_connected'] == true,
      isActive: json['is_active'] == true,
      isProviderActive: json['is_provider_active'] == true,
      connectInstruction: json['connect_instruction']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      authSchema: schema,
      balance: json['balance'] != null
          ? double.tryParse(json['balance'].toString())
          : null,
      balanceError: json['balance_error']?.toString(),
      virtualAccountNumber: json['virtual_account_number']?.toString(),
      virtualAccountName: json['virtual_account_name']?.toString(),
      virtualAccountBankName: json['virtual_account_bank_name']?.toString(),
      raw: json,
    );
  }
}
