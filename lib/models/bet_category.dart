class BetCategory {
  final int id;
  final String name;
  final String slug;
  final String icon;
  final bool isActive;

  BetCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.isActive,
  });

  factory BetCategory.fromJson(Map<String, dynamic> json) {
    return BetCategory(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      icon: json['icon'] ?? '🎯',
      isActive: json['is_active'] ?? true,
    );
  }
}
