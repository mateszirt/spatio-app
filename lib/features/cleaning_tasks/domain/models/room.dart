/// Szoba / Helyiség üzleti entitás
class Room {
  final String id;
  final String householdId;
  final String name;
  final int floor;
  final List<dynamic> polygonCoordinates; // JSONB poligon pontok az alaprajzhoz
  final int cleanlinessScore; // 0-100 közötti tisztasági index
  final DateTime createdAt;
  final DateTime updatedAt;

  const Room({
    required this.id,
    required this.householdId,
    required this.name,
    this.floor = 1,
    this.polygonCoordinates = const [],
    this.cleanlinessScore = 100,
    required this.createdAt,
    required this.updatedAt,
  });

  Room copyWith({
    String? id,
    String? householdId,
    String? name,
    int? floor,
    List<dynamic>? polygonCoordinates,
    int? cleanlinessScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      floor: floor ?? this.floor,
      polygonCoordinates: polygonCoordinates ?? this.polygonCoordinates,
      cleanlinessScore: cleanlinessScore ?? this.cleanlinessScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Room && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
