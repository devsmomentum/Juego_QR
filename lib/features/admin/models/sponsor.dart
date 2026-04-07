class Sponsor {
  final String id;
  final String name;
  final String planType; // 'bronce', 'plata', 'oro'
  final String? logoUrl;
  final String? bannerUrl;
  final String? targetUrl;
  final String? minigameAssetUrl;
  final bool isActive;
  final int weight;
  final DateTime createdAt;

  Sponsor({
    required this.id,
    required this.name,
    required this.planType,
    this.logoUrl,
    this.bannerUrl,
    this.targetUrl,
    this.minigameAssetUrl,
    required this.isActive,
    this.weight = 1,
    required this.createdAt,
  });

  factory Sponsor.fromJson(Map<String, dynamic> json) {
    return Sponsor(
      id: json['id'],
      name: json['name'],
      planType: json['plan_type'],
      logoUrl: json['logo_url'],
      bannerUrl: json['banner_url'],
      targetUrl: json['target_url'],
      minigameAssetUrl: json['minigame_asset_url'],
      isActive: json['is_active'] ?? true,
      weight: json['weight'] ?? _defaultWeight(json['plan_type']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  static int _defaultWeight(String? planType) {
    switch (planType?.toLowerCase()) {
      case 'oro':    return 5;
      case 'plata':  return 3;
      case 'bronce': return 1;
      default:       return 1;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'plan_type': planType,
      'logo_url': logoUrl,
      'banner_url': bannerUrl,
      'target_url': targetUrl,
      'minigame_asset_url': minigameAssetUrl,
      'is_active': isActive,
    };
  }

  Sponsor copyWith({
    String? id,
    String? name,
    String? planType,
    String? logoUrl,
    String? bannerUrl,
    String? targetUrl,
    String? minigameAssetUrl,
    bool? isActive,
    int? weight,
    DateTime? createdAt,
  }) {
    return Sponsor(
      id: id ?? this.id,
      name: name ?? this.name,
      planType: planType ?? this.planType,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      targetUrl: targetUrl ?? this.targetUrl,
      minigameAssetUrl: minigameAssetUrl ?? this.minigameAssetUrl,
      isActive: isActive ?? this.isActive,
      weight: weight ?? this.weight,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // --- Plan Capabilities ---
  bool get hasOverlayBanner => true; // All plans (bronce, plata, oro)

  // Only Oro (Gold) has custom minigame assets (food/elements)
  bool get hasMinigameAssets => planType.toLowerCase() == 'oro';

  // Plata (Silver) and Oro (Gold) have video ads
  bool get hasVideoAds =>
      planType.toLowerCase() == 'plata' || planType.toLowerCase() == 'oro';

  // Plata (Silver) and Oro (Gold) have "Sponsored By" banner
  bool get hasSponsoredByBanner =>
      planType.toLowerCase() == 'plata' || planType.toLowerCase() == 'oro';
}
