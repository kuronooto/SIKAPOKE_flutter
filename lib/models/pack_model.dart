import 'package:flutter/material.dart';

class PackModel {
  final String id;
  final String name;
  final Color color;
  final String imagePath;
  final int rarityLevel; // レア度 (1-5)

  const PackModel({
    required this.id,
    required this.name,
    required this.color,
    required this.imagePath,
    required this.rarityLevel,
  });
}

class CardResult {
  final String id;
  final String name;
  final String imagePath;
  final int rarityLevel;
  final String description;

  const CardResult({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.rarityLevel,
    required this.description,
  });

  String get rarityStars {
    return '★' * rarityLevel;
  }
}
