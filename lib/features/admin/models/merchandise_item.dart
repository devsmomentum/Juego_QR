import 'package:flutter/foundation.dart';

class MerchandiseItem {
  final String id;
  final String name;
  final String? subtitle;
  final String category;
  final int priceClovers;
  final String? imageUrl;
  final String? description;
  final int stock;
  final bool isAvailable;
  final DateTime createdAt;

  MerchandiseItem({
    required this.id,
    required this.name,
    this.subtitle,
    required this.category,
    required this.priceClovers,
    this.imageUrl,
    this.description,
    this.stock = 0,
    this.isAvailable = true,
    required this.createdAt,
  });

  factory MerchandiseItem.fromJson(Map<String, dynamic> json) {
    return MerchandiseItem(
      id: json['id'],
      name: json['name'] ?? '',
      subtitle: json['subtitle'],
      category: json['category'] ?? 'General',
      priceClovers: json['price_clovers'] ?? 0,
      imageUrl: json['image_url'],
      description: json['description'],
      stock: json['stock'] ?? 0,
      isAvailable: json['is_available'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'subtitle': subtitle,
      'category': category,
      'price_clovers': priceClovers,
      'image_url': imageUrl,
      'description': description,
      'stock': stock,
      'is_available': isAvailable,
    };
  }

  MerchandiseItem copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? category,
    int? priceClovers,
    String? imageUrl,
    String? description,
    int? stock,
    bool? isAvailable,
    DateTime? createdAt,
  }) {
    return MerchandiseItem(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      priceClovers: priceClovers ?? this.priceClovers,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      stock: stock ?? this.stock,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class MerchandiseRedemption {
  final String id;
  final String userId;
  final String itemId;
  final String status;
  final int ptsPaid;
  final String? adminNotes;
  final DateTime createdAt;
  
  // Joins
  final String? userName;
  final String? itemName;
  final String? itemImageUrl;

  MerchandiseRedemption({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.status,
    required this.ptsPaid,
    this.adminNotes,
    required this.createdAt,
    this.userName,
    this.itemName,
    this.itemImageUrl,
  });

  factory MerchandiseRedemption.fromJson(Map<String, dynamic> json) {
    return MerchandiseRedemption(
      id: json['id'],
      userId: json['user_id'],
      itemId: json['item_id'],
      status: json['status'] ?? 'pending',
      ptsPaid: json['pts_paid'] ?? 0,
      adminNotes: json['admin_notes'],
      createdAt: DateTime.parse(json['created_at']),
      userName: json['profiles']?['name'],
      itemName: json['merchandise_items']?['name'],
      itemImageUrl: json['merchandise_items']?['image_url'],
    );
  }
}
