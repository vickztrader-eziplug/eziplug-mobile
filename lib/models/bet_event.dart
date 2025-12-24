import 'package:cashpoint/models/bet_odd.dart';

class BetEvent {
  final int id;
  final int categoryId;
  final String name;
  final String? description;
  final DateTime eventDate;
  final String status;
  final String? homeTeam;
  final String? awayTeam;
  final String? league;
  final String? venue;
  final List<BetOdd>? odds;

  BetEvent({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.eventDate,
    required this.status,
    this.homeTeam,
    this.awayTeam,
    this.league,
    this.venue,
    this.odds,
  });

  factory BetEvent.fromJson(Map<String, dynamic> json) {
    return BetEvent(
      id: json['id'],
      categoryId: json['category_id'],
      name: json['name'],
      description: json['description'],
      eventDate: DateTime.parse(json['event_date']),
      status: json['status'],
      homeTeam: json['home_team'],
      awayTeam: json['away_team'],
      league: json['league'],
      venue: json['venue'],
      odds: json['odds'] != null
          ? (json['odds'] as List).map((o) => BetOdd.fromJson(o)).toList()
          : null,
    );
  }
}
