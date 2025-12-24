import 'package:cashpoint/models/bet_event.dart';
import 'package:cashpoint/models/bet_odd.dart';

class BetTransaction {
  final int id;
  final int userId;
  final int eventId;
  final int oddId;
  final double amount;
  final double potentialWin;
  final String status;
  final String? result;
  final String reference;
  final DateTime createdAt;
  final BetEvent? event;
  final BetOdd? odd;

  BetTransaction({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.oddId,
    required this.amount,
    required this.potentialWin,
    required this.status,
    this.result,
    required this.reference,
    required this.createdAt,
    this.event,
    this.odd,
  });

  factory BetTransaction.fromJson(Map<String, dynamic> json) {
    return BetTransaction(
      id: json['id'],
      userId: json['user_id'],
      eventId: json['event_id'],
      oddId: json['odd_id'],
      amount: double.parse(json['amount'].toString()),
      potentialWin: double.parse(json['potential_win'].toString()),
      status: json['status'],
      result: json['result'],
      reference: json['reference'],
      createdAt: DateTime.parse(json['created_at']),
      event: json['event'] != null ? BetEvent.fromJson(json['event']) : null,
      odd: json['odd'] != null ? BetOdd.fromJson(json['odd']) : null,
    );
  }
}