import 'dart:convert';
import '../../domain/models/room.dart';

class RoomDto {
  final String id;
  final String householdId;
  final String name;
  final int floor;
  final List<dynamic> polygonCoordinates;
  final int cleanlinessScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RoomDto({
    required this.id,
    required this.householdId,
    required this.name,
    required this.floor,
    required this.polygonCoordinates,
    required this.cleanlinessScore,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoomDto.fromDomain(Room room) {
    return RoomDto(
      id: room.id,
      householdId: room.householdId,
      name: room.name,
      floor: room.floor,
      polygonCoordinates: room.polygonCoordinates,
      cleanlinessScore: room.cleanlinessScore,
      createdAt: room.createdAt,
      updatedAt: room.updatedAt,
    );
  }

  Room toDomain() {
    return Room(
      id: id,
      householdId: householdId,
      name: name,
      floor: floor,
      polygonCoordinates: polygonCoordinates,
      cleanlinessScore: cleanlinessScore,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory RoomDto.fromJson(Map<String, dynamic> json) {
    final rawCoords = json['polygon_coordinates'];
    List<dynamic> coords = [];
    if (rawCoords is List) {
      coords = rawCoords;
    } else if (rawCoords is String && rawCoords.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCoords);
        if (decoded is List) coords = decoded;
      } catch (_) {}
    }

    return RoomDto(
      id: json['id']?.toString() ?? '',
      householdId: json['household_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Room',
      floor: (json['floor'] is num)
          ? (json['floor'] as num).toInt()
          : (int.tryParse(json['floor']?.toString() ?? '') ?? 1),
      polygonCoordinates: coords,
      cleanlinessScore: (json['cleanliness_score'] is num)
          ? (json['cleanliness_score'] as num).toInt()
          : (int.tryParse(json['cleanliness_score']?.toString() ?? '') ?? 100),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'name': name,
      'floor': floor,
      'polygon_coordinates': polygonCoordinates,
      'cleanliness_score': cleanlinessScore,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
