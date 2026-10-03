import 'dart:ui';
import '../../domain/models/room.dart';

/// Alaprajz geometriai segédeszközök: Grid Snap és Ray-Casting Hit Test
class GeometryUtils {
  GeometryUtils._();

  /// 1. GRID SNAP ALGORITMUS:
  /// Az érintési koordinátát a legközelebbi 20 pixeles virtuális rács metszéspontjára kerekíti.
  static Offset snapToGrid(Offset point, {double gridSize = 20.0}) {
    final snappedX = (point.dx / gridSize).roundToDouble() * gridSize;
    final snappedY = (point.dy / gridSize).roundToDouble() * gridSize;
    return Offset(snappedX, snappedY);
  }

  /// 2. RAY-CASTING HIT TEST ALGORITMUS (Jordan Curve Theorem):
  /// Megállapítja, hogy a vizsgált [point] pont a [polygon] zárt poligon belsejében van-e.
  /// Egy vízszintes sugarat vetítünk jobbra (+X irányba) a pontból, és megszámoljuk,
  /// hányszor metszi a poligon éleit. Ha a metszések száma páratlan — a pont bent van.
  static bool isPointInPolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;
    final px = point.dx;
    final py = point.dy;

    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].dx;
      final yi = polygon[i].dy;
      final xj = polygon[j].dx;
      final yj = polygon[j].dy;

      // Ellenőrizzük, hogy a sugár metszi-e a (V_i, V_j) szakaszt
      final intersect = ((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / (yj - yi) + xi);

      if (intersect) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Keresés a szobák között Ray-Casting algoritmussal.
  /// Visszaadja az első szobát, amely tartalmazza a megadott pontot, vagy null-t.
  static Room? findRoomAtPoint(Offset point, List<Room> rooms) {
    // Visszafelé iterálunk, hogy a legfelső/legutóbb rajzolt szobát találjuk meg először
    for (int i = rooms.length - 1; i >= 0; i--) {
      final room = rooms[i];
      final vertices = roomToPolygon(room);
      if (isPointInPolygon(point, vertices)) {
        return room;
      }
    }
    return null;
  }

  /// Segédfüggvény: Room entitásból `List<Offset>` csúcspontok kinyerése
  static List<Offset> roomToPolygon(Room room) {
    final points = <Offset>[];
    for (final coord in room.polygonCoordinates) {
      if (coord is Map) {
        final x = (coord['x'] as num?)?.toDouble() ?? 0.0;
        final y = (coord['y'] as num?)?.toDouble() ?? 0.0;
        points.add(Offset(x, y));
      } else if (coord is List && coord.length >= 2) {
        final x = (coord[0] as num?)?.toDouble() ?? 0.0;
        final y = (coord[1] as num?)?.toDouble() ?? 0.0;
        points.add(Offset(x, y));
      }
    }
    return points;
  }

  /// Poligon súlypontjának (centroid) számítása szövegcímkék elhelyezéséhez
  static Offset computeCentroid(List<Offset> polygon) {
    if (polygon.isEmpty) return Offset.zero;
    if (polygon.length == 1) return polygon.first;
    if (polygon.length == 2) {
      return Offset((polygon[0].dx + polygon[1].dx) / 2, (polygon[0].dy + polygon[1].dy) / 2);
    }

    double signedArea = 0.0;
    double cx = 0.0;
    double cy = 0.0;

    for (int i = 0; i < polygon.length; i++) {
      final x0 = polygon[i].dx;
      final y0 = polygon[i].dy;
      final x1 = polygon[(i + 1) % polygon.length].dx;
      final y1 = polygon[(i + 1) % polygon.length].dy;

      final a = x0 * y1 - x1 * y0;
      signedArea += a;
      cx += (x0 + x1) * a;
      cy += (y0 + y1) * a;
    }

    signedArea *= 0.5;
    if (signedArea.abs() < 1e-4) {
      // Elfajult poligon esetén számtani közép
      double sumX = 0;
      double sumY = 0;
      for (final p in polygon) {
        sumX += p.dx;
        sumY += p.dy;
      }
      return Offset(sumX / polygon.length, sumY / polygon.length);
    }

    cx /= (6.0 * signedArea);
    cy /= (6.0 * signedArea);

    return Offset(cx, cy);
  }
}
