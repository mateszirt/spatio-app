import 'package:flutter/material.dart';
import '../../domain/models/room.dart';
import '../../domain/models/furniture_item.dart';
import 'geometry_utils.dart';
import 'furniture_catalog.dart';
import '../../../../core/services/presence_service.dart';

/// 2D Interaktív Alaprajz CustomPainter (RepaintBoundary-vel optimalizálva)
class CustomFloorPainter extends CustomPainter {
  final List<Room> rooms;
  final Room? selectedRoom;
  final List<FurnitureItem> furnitureItems;
  final FurnitureItem? selectedFurniture;
  final List<Offset> currentDrawingPoints;
  final Offset? previewPoint;
  final bool showGrid;
  final double gridSize;
  final Size canvasSize;
  final int currentFloor;
  final List<FurnitureItem> lowerFloorStairs;
  final List<UserPresence> activePresences;

  // Sims-stílusú bútor előnézet paraméterei
  final Offset? ghostPosition;
  final String? ghostFurnitureName;
  final String? ghostCategory;
  final double ghostWidth;
  final double ghostHeight;
  final double ghostRotation;
  final bool isGhostInsideRoom;
  final Map<String, int>? roomCleanlinessScores;

  CustomFloorPainter({
    required this.rooms,
    this.selectedRoom,
    this.furnitureItems = const [],
    this.selectedFurniture,
    required this.currentDrawingPoints,
    this.previewPoint,
    this.showGrid = true,
    this.gridSize = 20.0,
    required this.canvasSize,
    this.currentFloor = 1,
    this.lowerFloorStairs = const [],
    this.ghostPosition,
    this.ghostFurnitureName,
    this.ghostCategory,
    this.ghostWidth = 60.0,
    this.ghostHeight = 60.0,
    this.ghostRotation = 0.0,
    this.isGhostInsideRoom = false,
    this.roomCleanlinessScores,
    this.activePresences = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Háttér és 20 pixeles virtuális rács kirajzolása
    if (showGrid) {
      _drawGrid(canvas, canvasSize);
    }

    // 2. Alsóbb emeletről érkező lépcsők (egyedi, sötét blueprint alaprajzzal)
    for (final stair in lowerFloorStairs) {
      _drawStairArrivalCutout(canvas, stair);
    }

    // 3. Létező szobák poligonjainak és falainak kirajzolása (csak az aktuális emelet)
    for (final room in rooms) {
      final isSelected = selectedRoom?.id == room.id;
      _drawRoom(canvas, room, isSelected: isSelected);
    }

    // 4. Szobákban lévő bútorok kirajzolása (csak az aktuális emelet)
    for (final item in furnitureItems) {
      final isSelected = selectedFurniture?.id == item.id;
      _drawFurnitureItem(canvas, item, isSelected: isSelected);
    }

    // 5. Folyamatban lévő szobarajzolás (Drawing In-Progress) kirajzolása
    if (currentDrawingPoints.isNotEmpty) {
      _drawActiveDrawing(canvas);
    }

    // 6. Sims-stílusú Ghost Bútor (kurzort / ujjat követő interaktív előnézet)
    if (ghostPosition != null) {
      _drawGhostFurniture(canvas);
    }
  }

  /// 20 pixeles virtuális rácsvonalak és metszéspontok kirajzolása
  void _drawGrid(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.6;

    final majorPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.0;

    final dotPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.5)
      ..strokeWidth = 1.5;

    final majorStep = gridSize * 5; // 100 px-enként fő rácsvonal

    // Függőleges vonalak
    for (double x = 0; x <= size.width; x += gridSize) {
      final isMajor = (x % majorStep).abs() < 0.1;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMajor ? majorPaint : minorPaint,
      );
    }

    // Vízszintes vonalak
    for (double y = 0; y <= size.height; y += gridSize) {
      final isMajor = (y % majorStep).abs() < 0.1;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isMajor ? majorPaint : minorPaint,
      );
    }

    // Metszéspontok (rácspontok kiemelése kis pontokkal)
    for (double x = 0; x <= size.width; x += majorStep) {
      for (double y = 0; y <= size.height; y += majorStep) {
        canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
      }
    }
  }

  /// Egyedi szoba kirajzolása: kitöltés a tisztaság alapján, falak és címke
  void _drawRoom(Canvas canvas, Room room, {required bool isSelected}) {
    final vertices = GeometryUtils.roomToPolygon(room);
    if (vertices.length < 3) return;

    final path = Path()..moveTo(vertices.first.dx, vertices.first.dy);
    for (int i = 1; i < vertices.length; i++) {
      path.lineTo(vertices[i].dx, vertices[i].dy);
    }
    path.close();

    // Szín meghatározása a dinamikus cleanliness_score szerint
    final score = roomCleanlinessScores?[room.id] ?? room.cleanlinessScore;
    Color baseColor;
    if (score >= 80) {
      baseColor = const Color(0xFF00897B); // Green/Teal - Clean
    } else if (score >= 50) {
      baseColor = const Color(0xFFF59E0B); // Amber - Moderate
    } else {
      baseColor = const Color(0xFFEF4444); // Red - Needs Attention
    }

    // 1. Poligon belső kitöltése (finom építészeti padlóárnyalat, hogy a bútorok maximálisan kitűnjenek)
    final fillPaint = Paint()
      ..color = baseColor.withValues(alpha: isSelected ? 0.20 : 0.10)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 2. Kijelölési halo/effektus
    if (isSelected) {
      final highlightPaint = Paint()
        ..color = const Color(0xFF00897B).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0;
      canvas.drawPath(path, highlightPaint);
    }

    // Collaborator Presence Highlight (ha egy másik családtag épp ebben a szobában tevékenykedik)
    UserPresence? presenceInRoom;
    for (final p in activePresences) {
      if (p.roomId == room.id && p.isBusy) {
        presenceInRoom = p;
        break;
      }
    }

    if (presenceInRoom != null) {
      final presenceGlow = Paint()
        ..color = const Color(0xFF6366F1).withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0;
      canvas.drawPath(path, presenceGlow);
    }

    // 3. Falszerkezet (Határozott sötét építészeti fal kontúr)
    final wallPaint = Paint()
      ..color = isSelected ? const Color(0xFF004D40) : const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 4.0 : 3.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, wallPaint);

    // 4. Csúcspontok jelölése apró sarokpontokkal
    final cornerPaint = Paint()
      ..color = isSelected ? const Color(0xFF00897B) : const Color(0xFF475569)
      ..style = PaintingStyle.fill;
    for (final v in vertices) {
      canvas.drawCircle(v, 3.5, cornerPaint);
    }

    // 5. Szobainformációs címke (Centroid pozícióban)
    final centroid = GeometryUtils.computeCentroid(vertices);
    _drawRoomLabel(canvas, centroid, room, score, baseColor, isSelected, presenceInRoom: presenceInRoom);
  }

  /// Szobainformációs címke badge megjelenítése
  void _drawRoomLabel(
    Canvas canvas,
    Offset center,
    Room room,
    int score,
    Color statusColor,
    bool isSelected, {
    UserPresence? presenceInRoom,
  }) {
    const textStyle = TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 13,
      fontWeight: FontWeight.bold,
      fontFamily: 'Roboto',
    );

    final scoreStyle = TextStyle(
      color: statusColor,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      fontFamily: 'Roboto',
    );

    final titleSpan = TextSpan(text: room.name, style: textStyle);
    final titlePainter = TextPainter(
      text: titleSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final scoreSpan = TextSpan(text: '$score% Clean', style: scoreStyle);
    final scorePainter = TextPainter(
      text: scoreSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final cardWidth = (titlePainter.width > scorePainter.width ? titlePainter.width : scorePainter.width) + 20;
    final cardHeight = titlePainter.height + scorePainter.height + 12;

    final cardRect = Rect.fromCenter(
      center: center,
      width: cardWidth,
      height: cardHeight,
    );

    // Kártya háttér lekerekített sarkokkal és finom árnyékkal
    final cardPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final cardBorder = Paint()
      ..color = isSelected ? statusColor : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1.8 : 1.0;

    final rrect = RRect.fromRectAndRadius(cardRect, const Radius.circular(8));
    canvas.drawRRect(rrect, cardPaint);
    canvas.drawRRect(rrect, cardBorder);

    // Szöveg kirajzolása
    titlePainter.paint(
      canvas,
      Offset(cardRect.left + (cardWidth - titlePainter.width) / 2, cardRect.top + 4),
    );
    scorePainter.paint(
      canvas,
      Offset(cardRect.left + (cardWidth - scorePainter.width) / 2, cardRect.top + titlePainter.height + 5),
    );

    // Collaborator Presence Pill on canvas
    if (presenceInRoom != null) {
      final presenceText = '${presenceInRoom.userAvatar} ${presenceInRoom.userName} is here';
      final pSpan = TextSpan(
        text: presenceText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
      );
      final pPainter = TextPainter(text: pSpan, textDirection: TextDirection.ltr)..layout();
      final pWidth = pPainter.width + 16;
      final pHeight = pPainter.height + 6;
      final pRect = Rect.fromCenter(
        center: Offset(center.dx, cardRect.top - pHeight / 2 - 4),
        width: pWidth,
        height: pHeight,
      );
      final pPaint = Paint()
        ..color = const Color(0xFF6366F1)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(pRect, const Radius.circular(10)), pPaint);
      pPainter.paint(canvas, Offset(pRect.left + 8, pRect.top + 3));
    }
  }

  /// Éppen rajzolás alatt lévő szoba pontjai, falai és preview vonala
  void _drawActiveDrawing(Canvas canvas) {
    final points = currentDrawingPoints;

    final linePaint = Paint()
      ..color = const Color(0xFF00897B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    final previewLinePaint = Paint()
      ..color = const Color(0xFF00897B).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final pointPaint = Paint()
      ..color = const Color(0xFF00897B)
      ..style = PaintingStyle.fill;

    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Eddig lerakott falak rajzolása
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // Előnézeti vonal az utolsó ponttól az aktuális rácspozícióig
    if (previewPoint != null && points.isNotEmpty) {
      canvas.drawLine(points.last, previewPoint!, previewLinePaint);

      // Zárási előnézet: ha közel van az első ponthoz, jelezzük a poligon bezárását
      if (points.length >= 3 && (previewPoint! - points.first).distance < 25.0) {
        final closeHintPaint = Paint()
          ..color = Colors.greenAccent.shade700.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(points.first, 14.0, closeHintPaint);
      }
    }

    // Csúcspontok kirajzolása
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final isFirst = i == 0;

      // Első pont kiemelése (ide kell kattintani a bezáráshoz)
      if (isFirst) {
        canvas.drawCircle(p, 8.0, Paint()..color = const Color(0xFF00897B).withValues(alpha: 0.3));
      }

      canvas.drawCircle(p, isFirst ? 6.0 : 5.0, pointPaint);
      canvas.drawCircle(p, isFirst ? 6.0 : 5.0, pointBorderPaint);
    }

    // Grid Snap kurzor / célpont indikátor
    if (previewPoint != null) {
      final snapTargetPaint = Paint()
        ..color = const Color(0xFF00897B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(previewPoint!, 7.0, snapTargetPaint);
      canvas.drawCircle(previewPoint!, 2.5, pointPaint);
    }
  }

  /// Felső emeleti lépcső lejáró (Egyedi, Sötét Blueprint alaprajzi kivágás)
  void _drawStairArrivalCutout(Canvas canvas, FurnitureItem stair) {
    final x = (stair.positionCoordinates['x'] as num?)?.toDouble() ?? 0.0;
    final y = (stair.positionCoordinates['y'] as num?)?.toDouble() ?? 0.0;
    final w = (stair.positionCoordinates['width'] as num?)?.toDouble() ?? 75.0;
    final h = (stair.positionCoordinates['height'] as num?)?.toDouble() ?? 110.0;
    final center = Offset(x, y);
    final rect = Rect.fromCenter(center: center, width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    // 1. Sötét Blueprint háttér (#0F172A)
    final bgPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // 2. Neon Ciánkék sraffozás / lépcsőfokok
    final stepPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.5)
      ..strokeWidth = 1.6;
    const numSteps = 6;
    final stepGap = h / (numSteps + 1);
    for (int i = 1; i <= numSteps; i++) {
      final sy = rect.top + i * stepGap;
      canvas.drawLine(Offset(rect.left + 6, sy), Offset(rect.right - 6, sy), stepPaint);
    }

    // 3. Világító cián keret
    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, borderPaint);

    // 4. Lejáró ikon és felirat
    final arrowSpan = const TextSpan(
      text: '⬇',
      style: TextStyle(fontSize: 16, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
    );
    final arrowPainter = TextPainter(text: arrowSpan, textDirection: TextDirection.ltr)..layout();
    arrowPainter.paint(
      canvas,
      Offset(center.dx - arrowPainter.width / 2, center.dy - arrowPainter.height / 2 - 8),
    );

    final labelSpan = const TextSpan(
      text: 'Lépcső lejáró\n(Alsóbb szintről)',
      style: TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontFamily: 'Roboto',
      ),
    );
    final labelPainter = TextPainter(
      text: labelSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(canvas, Offset(center.dx - labelPainter.width / 2, center.dy + 8));
  }

  /// Építészeti lépcső megjelenítése az alsóbb szinten
  void _drawStaircaseItem(
    Canvas canvas,
    Offset center,
    double w,
    double h, {
    required bool isSelected,
  }) {
    final rect = Rect.fromCenter(center: center, width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    // Fa/világos háttér
    final bgPaint = Paint()
      ..color = isSelected ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // Lépcsőfokok
    final stepPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.5;
    const numSteps = 6;
    final stepGap = h / (numSteps + 1);
    for (int i = 1; i <= numSteps; i++) {
      final sy = rect.top + i * stepGap;
      canvas.drawLine(Offset(rect.left + 5, sy), Offset(rect.right - 5, sy), stepPaint);
    }

    // Irányvonal
    final linePaint = Paint()
      ..color = const Color(0xFF00897B)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(center.dx, rect.bottom - 12), Offset(center.dx, rect.top + 16), linePaint);

    final arrowSpan = const TextSpan(
      text: '▲',
      style: TextStyle(fontSize: 14, color: Color(0xFF00897B), fontWeight: FontWeight.bold),
    );
    final arrowPainter = TextPainter(text: arrowSpan, textDirection: TextDirection.ltr)..layout();
    arrowPainter.paint(canvas, Offset(center.dx - arrowPainter.width / 2, rect.top + 4));

    // Keret
    final borderPaint = Paint()
      ..color = isSelected ? const Color(0xFFD97706) : const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.5 : 1.5;
    canvas.drawRRect(rrect, borderPaint);

    // Felirat
    final textSpan = const TextSpan(
      text: 'Lépcső (Fel)',
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, rect.bottom + 4));
  }

  /// Bútor / Berendezési tárgy vizuális kirajzolása (Kiemelt, magas kontrasztú megjelenés)
  void _drawFurnitureItem(
    Canvas canvas,
    FurnitureItem item, {
    required bool isSelected,
  }) {
    final x = (item.positionCoordinates['x'] as num?)?.toDouble() ?? 0.0;
    final y = (item.positionCoordinates['y'] as num?)?.toDouble() ?? 0.0;
    final center = Offset(x, y);

    final isStairs = FurnitureCatalog.isStairs(item.name, item.category);
    final w = (item.positionCoordinates['width'] as num?)?.toDouble() ?? (isStairs ? 75.0 : 55.0);
    final h = (item.positionCoordinates['height'] as num?)?.toDouble() ?? (isStairs ? 120.0 : 55.0);
    final rotation = (item.positionCoordinates['rotation'] as num?)?.toDouble() ?? 0.0;

    if (isStairs) {
      _drawStaircaseItem(canvas, center, w, h, isSelected: isSelected);
      return;
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotation != 0) {
      canvas.rotate(rotation * 3.141592653589793 / 180.0);
    }

    // Bútorkártya mérete és pozíciója
    final boxRect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final boxRRect = RRect.fromRectAndRadius(boxRect, const Radius.circular(8));

    // 1. Erőteljes dupla árnyék (hogy a bútor lebegjen a padló felett és elváljon a szobától)
    final shadowPaint1 = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawRRect(boxRRect.shift(const Offset(0, 3)), shadowPaint1);

    final shadowPaint2 = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(boxRRect.shift(const Offset(0, 6)), shadowPaint2);

    // Kijelölési ragyogás (Selection Glow)
    if (isSelected) {
      final glowPaint = Paint()
        ..color = const Color(0xFF00897B).withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(boxRRect, glowPaint);
    }

    // 2. Kategória- és anyagspecifikus prémium kitöltés (Magas kontraszt a szoba padlójával)
    final catColor = FurnitureCatalog.colorFor(item.name, item.category);
    final fType = FurnitureCatalog.byName(item.name);
    final material = fType?.material ?? 'wood';

    Color bodyColor;
    if (isSelected) {
      bodyColor = const Color(0xFFE6FFFA); // Subtle mint glow
    } else {
      switch (material) {
        case 'wood':
          bodyColor = const Color(0xFFFFFBEB); // Warm Cream / Natural Wood
          break;
        case 'fabric':
          bodyColor = const Color(0xFFF8FAFC); // Cozy Linen White
          break;
        case 'porcelain':
          bodyColor = const Color(0xFFFFFFFF); // Glossy Ceramic White
          break;
        case 'appliance':
        case 'metal':
          bodyColor = const Color(0xFFF1F5F9); // Brushed Silver
          break;
        case 'plant':
          bodyColor = const Color(0xFFF0FDF4); // Soft Botanical Green
          break;
        default:
          bodyColor = const Color(0xFFFFFFFF);
      }
    }

    final bgPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(boxRRect, bgPaint);

    // 3. Kategória Színcsík a bútor felső élén (Visual Category Accent Bar)
    final clipPath = Path()..addRRect(boxRRect);
    canvas.save();
    canvas.clipPath(clipPath);

    final accentBarHeight = (h * 0.12).clamp(4.0, 7.0);
    final accentRect = Rect.fromLTWH(boxRect.left, boxRect.top, w, accentBarHeight);
    final accentPaint = Paint()
      ..color = catColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(accentRect, accentPaint);

    canvas.restore();

    // 4. Határozott, tiszta kontúrkeret (Sötét pala, nem folyik egybe a szobával)
    final borderPaint = Paint()
      ..color = isSelected ? const Color(0xFF00897B) : const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.5 : 1.6;
    canvas.drawRRect(boxRRect, borderPaint);

    // 5. Pontos Emoji / Ikon szimbólum a FurnitureCatalog-ból
    final iconChar = FurnitureCatalog.emojiFor(item.name, item.category);
    final iconSize = (w < h ? w : h) > 50 ? 20.0 : 16.0;

    final emojiSpan = TextSpan(
      text: iconChar,
      style: TextStyle(fontSize: iconSize),
    );
    final emojiPainter = TextPainter(
      text: emojiSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final emojiY = (h > 45) ? -emojiPainter.height / 2 - 3 : -emojiPainter.height / 2;
    emojiPainter.paint(
      canvas,
      Offset(-emojiPainter.width / 2, emojiY),
    );

    // 6. Bútor megnevezése jól olvasható, kontrasztos pill badge-ben
    if (h > 40 && w > 45) {
      final nameSpan = TextSpan(
        text: item.name,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: isSelected ? const Color(0xFF004D40) : const Color(0xFF0F172A),
        ),
      );
      final namePainter = TextPainter(
        text: nameSpan,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '..',
      )..layout(maxWidth: w - 8);

      final badgeRect = Rect.fromCenter(
        center: Offset(0, (h / 2) - (namePainter.height / 2) - 4),
        width: namePainter.width + 8,
        height: namePainter.height + 4,
      );
      final badgePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.fill;
      final badgeBorder = Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)), badgePaint);
      canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)), badgeBorder);

      namePainter.paint(
        canvas,
        Offset(-namePainter.width / 2, (h / 2) - namePainter.height - 4),
      );
    }

    // 7. Kijelölési sarokfogantyúk (Selection Handles)
    if (isSelected) {
      final handlePaint = Paint()
        ..color = const Color(0xFF00897B)
        ..style = PaintingStyle.fill;
      final handleBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      for (final offset in [
        boxRect.topLeft,
        boxRect.topRight,
        boxRect.bottomLeft,
        boxRect.bottomRight,
      ]) {
        canvas.drawCircle(offset, 3.5, handlePaint);
        canvas.drawCircle(offset, 3.5, handleBorder);
      }
    }

    canvas.restore();
  }

  /// Sims-stílusú Ghost Bútor (kurzort / ujjat követő interaktív előnézet)
  void _drawGhostFurniture(Canvas canvas) {
    if (ghostPosition == null) return;

    final center = ghostPosition!;
    final w = ghostWidth;
    final h = ghostHeight;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (ghostRotation != 0) {
      canvas.rotate(ghostRotation * 3.141592653589793 / 180.0);
    }

    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    final color = isGhostInsideRoom ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    // Áttetsző kitöltés
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, fillPaint);

    // Határvonal
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, borderPaint);

    // Ikon a FurnitureCatalog-ból
    final iconChar = FurnitureCatalog.emojiFor(ghostFurnitureName, ghostCategory);

    final iconSpan = TextSpan(text: iconChar, style: const TextStyle(fontSize: 20));
    final iconPainter = TextPainter(text: iconSpan, textDirection: TextDirection.ltr)..layout();
    iconPainter.paint(
      canvas,
      Offset(-iconPainter.width / 2, -iconPainter.height / 2 - 8),
    );

    // Méret jelző
    final dimSpan = TextSpan(
      text: '${w.toInt()}×${h.toInt()} px',
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
    );
    final dimPainter = TextPainter(text: dimSpan, textDirection: TextDirection.ltr)..layout();
    dimPainter.paint(canvas, Offset(-dimPainter.width / 2, 8));

    // Státusz felirat alatta
    final statusText = isGhostInsideRoom ? '✓ Ready to place' : '⚠️ Must be inside room';
    final statusSpan = TextSpan(
      text: statusText,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: color,
        backgroundColor: Colors.white.withValues(alpha: 0.95),
      ),
    );
    final statusPainter = TextPainter(text: statusSpan, textDirection: TextDirection.ltr)..layout();
    statusPainter.paint(canvas, Offset(-statusPainter.width / 2, rect.bottom + 5));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomFloorPainter oldDelegate) {
    return oldDelegate.rooms != rooms ||
        oldDelegate.selectedRoom != selectedRoom ||
        oldDelegate.furnitureItems != furnitureItems ||
        oldDelegate.selectedFurniture != selectedFurniture ||
        oldDelegate.currentDrawingPoints != currentDrawingPoints ||
        oldDelegate.previewPoint != previewPoint ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.gridSize != gridSize ||
        oldDelegate.currentFloor != currentFloor ||
        oldDelegate.lowerFloorStairs != lowerFloorStairs ||
        oldDelegate.ghostPosition != ghostPosition ||
        oldDelegate.ghostWidth != ghostWidth ||
        oldDelegate.ghostHeight != ghostHeight ||
        oldDelegate.ghostRotation != ghostRotation ||
        oldDelegate.isGhostInsideRoom != isGhostInsideRoom ||
        oldDelegate.roomCleanlinessScores != roomCleanlinessScores;
  }
}
