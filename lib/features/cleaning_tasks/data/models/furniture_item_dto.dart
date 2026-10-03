import 'dart:convert';
import '../../domain/models/furniture_item.dart';

class FurnitureItemDto {
  final String id;
  final String roomId;
  final String name;
  final String? category;
  final Map<String, dynamic> positionCoordinates;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FurnitureItemDto({
    required this.id,
    required this.roomId,
    required this.name,
    this.category,
    this.positionCoordinates = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory FurnitureItemDto.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> coords = {};
    final rawCoords = json['position_coordinates'];
    if (rawCoords is Map<String, dynamic>) {
      coords = rawCoords;
    } else if (rawCoords is String && rawCoords.isNotEmpty) {
      try {
        coords = jsonDecode(rawCoords) as Map<String, dynamic>;
      } catch (_) {}
    }

    return FurnitureItemDto(
      id: json['id']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category'] as String?,
      positionCoordinates: coords,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'name': name,
      'category': category,
      'position_coordinates': positionCoordinates,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FurnitureItem toDomain() {
    return FurnitureItem(
      id: id,
      roomId: roomId,
      name: name,
      category: category,
      positionCoordinates: positionCoordinates,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory FurnitureItemDto.fromDomain(FurnitureItem item) {
    return FurnitureItemDto(
      id: item.id,
      roomId: item.roomId,
      name: item.name,
      category: item.category,
      positionCoordinates: item.positionCoordinates,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }
}
