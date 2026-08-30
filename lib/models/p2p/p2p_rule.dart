/// An automation rule from the /p2p/rules endpoints.
class P2pRule {
  static const typeAmountLimit = 'AMOUNT_LIMIT';
  static const typeDailyLimit = 'DAILY_LIMIT';
  static const typeWorkingHours = 'WORKING_HOURS';
  static const typeAllowedBanks = 'ALLOWED_BANKS';
  static const typeManualThreshold = 'MANUAL_THRESHOLD';
  static const typeNewUserDelay = 'NEW_USER_DELAY';
  static const typeMaxBadReviews = 'MAX_BAD_REVIEWS';
  static const typeMaxAvgReleaseTime = 'MAX_AVG_RELEASE_TIME';
  static const typeAutoMarkPayTime = 'AUTO_MARK_PAY_TIME';

  static const List<String> allTypes = [
    typeAmountLimit,
    typeDailyLimit,
    typeWorkingHours,
    typeAllowedBanks,
    typeManualThreshold,
    typeNewUserDelay,
    typeMaxBadReviews,
    typeMaxAvgReleaseTime,
    typeAutoMarkPayTime,
  ];

  static const actionApprove = 'APPROVE';
  static const actionReject = 'REJECT';
  static const actionManualReview = 'MANUAL_REVIEW';

  static const List<String> allActions = [
    actionApprove,
    actionReject,
    actionManualReview,
  ];

  final String id;
  final String name;
  final String type;
  final Map<String, dynamic> conditions;
  final String action;
  final int priority;
  final bool isActive;

  const P2pRule({
    required this.id,
    required this.name,
    required this.type,
    required this.conditions,
    required this.action,
    required this.priority,
    required this.isActive,
  });

  factory P2pRule.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> conditions = {};
    final rawConditions = json['conditions'];
    if (rawConditions is Map<String, dynamic>) {
      conditions = rawConditions;
    } else if (rawConditions is Map) {
      conditions = Map<String, dynamic>.from(rawConditions);
    }

    return P2pRule(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      conditions: conditions,
      action: json['action']?.toString() ?? '',
      priority: int.tryParse(json['priority']?.toString() ?? '') ?? 0,
      isActive: json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'conditions': conditions,
      'action': action,
      'priority': priority,
      'is_active': isActive,
    };
  }

  /// Human-readable label for a rule type, used in dropdowns/lists.
  static String typeLabel(String type) {
    switch (type) {
      case typeAmountLimit:
        return 'Amount Limit';
      case typeDailyLimit:
        return 'Daily Limit';
      case typeWorkingHours:
        return 'Working Hours';
      case typeAllowedBanks:
        return 'Allowed Banks';
      case typeManualThreshold:
        return 'Manual Threshold';
      case typeNewUserDelay:
        return 'New User Delay';
      case typeMaxBadReviews:
        return 'Max Bad Reviews';
      case typeMaxAvgReleaseTime:
        return 'Max Avg Release Time';
      case typeAutoMarkPayTime:
        return 'Auto Mark-Pay Time';
      default:
        return type;
    }
  }
}
