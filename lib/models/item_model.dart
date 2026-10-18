import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// ItemCategory enum + extension (mirrors the one in main.dart)
// ---------------------------------------------------------------------------

enum ItemCategory { tools, electronics, sports, camping, games }

extension CategoryX on ItemCategory {
  String get label => switch (this) {
        ItemCategory.tools => 'Tools',
        ItemCategory.electronics => 'Electronics',
        ItemCategory.sports => 'Sports',
        ItemCategory.camping => 'Camping',
        ItemCategory.games => 'Books & Games',
      };

  IconData get icon => switch (this) {
        ItemCategory.tools => Icons.build_rounded,
        ItemCategory.electronics => Icons.videocam_rounded,
        ItemCategory.sports => Icons.sports_cricket_rounded,
        ItemCategory.camping => Icons.landscape_rounded,
        ItemCategory.games => Icons.casino_rounded,
      };

  String get storageKey => name; // e.g. 'tools', 'electronics'

  static ItemCategory fromString(String value) {
    return ItemCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => ItemCategory.tools,
    );
  }
}

// ---------------------------------------------------------------------------
// ItemModel
// ---------------------------------------------------------------------------

class ItemModel {
  final String id;
  String name;
  ItemCategory category;
  String owner;      // display name of the owner
  String ownerId;    // backend user id ("seed" for demo items)
  String desc;
  int deposit;
  String imageUrl;   // optional photo URL
  final DateTime createdAt;

  ItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.owner,
    required this.ownerId,
    required this.desc,
    required this.deposit,
    this.imageUrl = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ItemModel.fromJson(Map<String, dynamic> json, String id) {
    return ItemModel(
      id: id,
      name: json['name'] as String? ?? '',
      category: CategoryX.fromString(json['category'] as String? ?? 'tools'),
      owner: json['owner'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      desc: json['desc'] as String? ?? '',
      deposit: (json['deposit'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String? ?? '',
      createdAt: (json['createdAt'] is String
              ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category.storageKey,
      'owner': owner,
      'ownerId': ownerId,
      'desc': desc,
      'deposit': deposit,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
