/// Bútor / Berendezési tárgy üzleti entitás
class FurnitureItem {
  final String id;
  final String roomId;
  final String name;
  final String? category;
  final Map<String, dynamic> positionCoordinates;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FurnitureItem({
    required this.id,
    required this.roomId,
    required this.name,
    this.category,
    this.positionCoordinates = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FurnitureItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
