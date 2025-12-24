class BetOdd {
  final int id;
  final int eventId;
  final String betType;
  final double oddValue;
  final bool isActive;

  BetOdd({
    required this.id,
    required this.eventId,
    required this.betType,
    required this.oddValue,
    required this.isActive,
  });

  factory BetOdd.fromJson(Map<String, dynamic> json) {
    return BetOdd(
      id: json['id'],
      eventId: json['event_id'],
      betType: json['bet_type'],
      oddValue: double.parse(json['odd_value'].toString()),
      isActive: json['is_active'] ?? true,
    );
  }
}
