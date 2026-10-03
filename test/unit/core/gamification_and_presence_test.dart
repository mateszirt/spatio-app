import 'package:flutter_test/flutter_test.dart';
import 'package:spatio_cleaning/core/services/gamification.dart';
import 'package:spatio_cleaning/core/services/presence_service.dart';

void main() {
  group('Gamification Service Tests', () {
    test('levelFor accurately maps lifetime points to levels and titles', () {
      expect(Gamification.levelFor(-50).number, equals(1));
      expect(Gamification.levelFor(0).number, equals(1));
      expect(Gamification.levelFor(0).title, equals('Fresh Sprout'));
      expect(Gamification.levelFor(0).emoji, equals('🌱'));
      expect(Gamification.levelFor(0).nextAt, equals(50));
      expect(Gamification.levelFor(0).isMax, isFalse);

      expect(Gamification.levelFor(49).number, equals(1));
      expect(Gamification.levelFor(50).number, equals(2));
      expect(Gamification.levelFor(50).title, equals('Tidy Helper'));
      expect(Gamification.levelFor(50).nextAt, equals(150));

      expect(Gamification.levelFor(150).number, equals(3));
      expect(Gamification.levelFor(150).title, equals('Sparkle Scout'));

      expect(Gamification.levelFor(300).number, equals(4));
      expect(Gamification.levelFor(300).title, equals('Clean Hero'));

      expect(Gamification.levelFor(600).number, equals(5));
      expect(Gamification.levelFor(600).title, equals('Dust Slayer'));

      expect(Gamification.levelFor(1000).number, equals(6));
      expect(Gamification.levelFor(1000).title, equals('Home Champion'));

      // Max Level (Living Legend)
      final maxLvl = Gamification.levelFor(1600);
      expect(maxLvl.number, equals(7));
      expect(maxLvl.title, equals('Living Legend'));
      expect(maxLvl.emoji, equals('👑'));
      expect(maxLvl.nextAt, isNull);
      expect(maxLvl.isMax, isTrue);

      final extremePointsLvl = Gamification.levelFor(50000);
      expect(extremePointsLvl.number, equals(7));
      expect(extremePointsLvl.isMax, isTrue);
    });

    test('GamificationLevel progress calculations and boundary clamps', () {
      // Level 2: min = 50, nextAt = 150, span = 100
      final lvl2 = Gamification.levelFor(50);
      expect(lvl2.progress(50), equals(0.0));
      expect(lvl2.progress(100), equals(0.5));
      expect(lvl2.progress(150), equals(1.0));
      expect(lvl2.progress(200), equals(1.0)); // clamped
      expect(lvl2.progress(10), equals(0.0)); // clamped

      // Level 7: Max level returns 1.0 progress always
      final maxLvl = Gamification.levelFor(1600);
      expect(maxLvl.progress(1600), equals(1.0));
      expect(maxLvl.progress(2500), equals(1.0));
    });

    test('badgesFor unlocking criteria', () {
      // 0 progress: all badges locked
      final badgesZero = Gamification.badgesFor(
        lifetimePoints: 0,
        streakDays: 0,
        tasksCompleted: 0,
      );
      expect(badgesZero.every((b) => !b.unlocked), isTrue);
      expect(badgesZero.length, equals(7));

      // 1 task completed
      final badges1Task = Gamification.badgesFor(
        lifetimePoints: 10,
        streakDays: 1,
        tasksCompleted: 1,
      );
      expect(badges1Task.firstWhere((b) => b.id == 'first_task').unlocked, isTrue);
      expect(badges1Task.firstWhere((b) => b.id == 'ten_tasks').unlocked, isFalse);

      // 10 tasks completed & 3 days streak
      final badges10Tasks = Gamification.badgesFor(
        lifetimePoints: 80,
        streakDays: 3,
        tasksCompleted: 10,
      );
      expect(badges10Tasks.firstWhere((b) => b.id == 'ten_tasks').unlocked, isTrue);
      expect(badges10Tasks.firstWhere((b) => b.id == 'streak_3').unlocked, isTrue);
      expect(badges10Tasks.firstWhere((b) => b.id == 'fifty_tasks').unlocked, isFalse);
      expect(badges10Tasks.firstWhere((b) => b.id == 'streak_7').unlocked, isFalse);
      expect(badges10Tasks.firstWhere((b) => b.id == 'points_100').unlocked, isFalse);

      // Max unlocks
      final badgesMax = Gamification.badgesFor(
        lifetimePoints: 1000,
        streakDays: 14,
        tasksCompleted: 100,
      );
      expect(badgesMax.every((b) => b.unlocked), isTrue);
    });

    test('streakLabel singular and plural', () {
      expect(Gamification.streakLabel(1), equals('1-day streak'));
      expect(Gamification.streakLabel(0), equals('0-day streak'));
      expect(Gamification.streakLabel(2), equals('2-day streak'));
      expect(Gamification.streakLabel(30), equals('30-day streak'));
    });
  });

  group('UserPresence Model Tests', () {
    final now = DateTime(2026, 10, 3, 12, 0, 0);

    test('UserPresence predicates and displayStatus resolution', () {
      final pPlacing = UserPresence(
        userId: 'u-1',
        userName: 'Anna',
        userAvatar: '👧',
        action: 'placing_furniture',
        detail: 'Placing Double Bed in Bedroom',
        roomId: 'r-1',
        floor: 1,
        updatedAt: now,
      );

      expect(pPlacing.isPlacingFurniture, isTrue);
      expect(pPlacing.isTypingTask, isFalse);
      expect(pPlacing.isDrawingRoom, isFalse);
      expect(pPlacing.isBusy, isTrue);
      expect(pPlacing.displayStatus, equals('Placing Double Bed in Bedroom'));

      final pTypingNoDetail = UserPresence(
        userId: 'u-2',
        userName: 'Bob',
        userAvatar: '👦',
        action: 'typing_task',
        detail: null,
        updatedAt: now,
      );
      expect(pTypingNoDetail.isTypingTask, isTrue);
      expect(pTypingNoDetail.isBusy, isFalse);
      expect(pTypingNoDetail.displayStatus, equals('Typing a task'));

      final pDrawing = UserPresence(
        userId: 'u-3',
        userName: 'Dad',
        userAvatar: '👨',
        action: 'drawing_room',
        updatedAt: now,
      );
      expect(pDrawing.isDrawingRoom, isTrue);
      expect(pDrawing.displayStatus, equals('Drawing a room'));

      final pIdle = UserPresence(
        userId: 'u-4',
        userName: 'Mom',
        userAvatar: '👩',
        action: 'idle',
        updatedAt: now,
      );
      expect(pIdle.displayStatus, equals('Online'));
    });

    test('UserPresence.fromMap and toMap roundtrip and missing field defaults', () {
      final map = {
        'user_id': 'u-99',
        'user_name': 'Sarah',
        'user_avatar': '👩‍💼',
        'action': 'drawing_room',
        'detail': 'Drawing Living Room',
        'room_id': 'r-99',
        'floor': 2,
        'updated_at': now.toIso8601String(),
      };

      final presence = UserPresence.fromMap(map);
      expect(presence.userId, equals('u-99'));
      expect(presence.userName, equals('Sarah'));
      expect(presence.userAvatar, equals('👩‍💼'));
      expect(presence.action, equals('drawing_room'));
      expect(presence.detail, equals('Drawing Living Room'));
      expect(presence.roomId, equals('r-99'));
      expect(presence.floor, equals(2));

      final serialized = presence.toMap();
      expect(serialized['user_id'], equals('u-99'));
      expect(serialized['floor'], equals(2));

      // Missing fields in fromMap fallback to safe defaults
      final emptyMap = <String, dynamic>{};
      final fallbackPresence = UserPresence.fromMap(emptyMap);
      expect(fallbackPresence.userId, equals(''));
      expect(fallbackPresence.userName, equals('Family Member'));
      expect(fallbackPresence.userAvatar, equals('👤'));
      expect(fallbackPresence.action, equals('idle'));
      expect(fallbackPresence.detail, isNull);
      expect(fallbackPresence.floor, isNull);
      expect(fallbackPresence.updatedAt, isA<DateTime>());
    });
  });
}
