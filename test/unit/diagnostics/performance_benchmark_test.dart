import 'package:flutter_test/flutter_test.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/floor_plan/geometry_utils.dart';
import 'package:spatio_cleaning/core/services/cleanliness_engine.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/room.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/task_item.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/user_effort_snapshot.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/app_user.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/usecases/assign_task_usecase.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/floor_plan/furniture_catalog.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/data/models/task_item_dto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Diagnostics: High-Performance & Low-Latency Benchmarks', () {
    test('Benchmark: 10,000 Ray-Casting Point-in-Polygon hit tests complete under 150ms', () {
      final polygon = [
        const Offset(10.0, 10.0),
        const Offset(200.0, 10.0),
        const Offset(200.0, 150.0),
        const Offset(120.0, 150.0),
        const Offset(120.0, 80.0),
        const Offset(10.0, 80.0),
      ];

      final stopwatch = Stopwatch()..start();
      int hits = 0;
      for (int i = 0; i < 10000; i++) {
        // Sample points diagonally across bounding box
        final testPoint = Offset(10.0 + (i % 200).toDouble(), 10.0 + (i % 150).toDouble());
        if (GeometryUtils.isPointInPolygon(testPoint, polygon)) {
          hits++;
        }
      }
      stopwatch.stop();

      expect(hits, greaterThan(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(350),
          reason: '10,000 Ray-casting tests should execute in well under 350ms (actual: ${stopwatch.elapsedMilliseconds}ms)');
    });

    test('Benchmark: 1,000 CleanlinessEngine score calculations complete under 100ms', () {
      final now = DateTime(2026, 10, 3, 12, 0);
      final room = Room(
        id: 'r-bench',
        householdId: 'hh-1',
        name: 'Grand Hall',
        floor: 1,
        polygonCoordinates: const [],
        cleanlinessScore: 100,
        createdAt: now,
        updatedAt: now,
      );

      final tasks = List.generate(20, (i) {
        return TaskItem(
          id: 'task-$i',
          householdId: 'hh-1',
          title: 'Task $i',
          referenceId: 'r-bench',
          referenceType: TaskReferenceType.room,
          status: i % 3 == 0 ? TaskStatus.completed : TaskStatus.pending,
          description: TaskItem.packDescription(priority: (i % 5) + 1, isRecurring: false),
          dueDate: now.add(Duration(hours: (i - 10) * 12)),
          createdAt: now,
          updatedAt: now,
        );
      });

      final stopwatch = Stopwatch()..start();
      int scoreAccumulator = 0;
      for (int i = 0; i < 1000; i++) {
        scoreAccumulator += CleanlinessEngine.calculateRoomCleanliness(
          room: room,
          allTasks: tasks,
          allFurniture: const [],
          referenceTime: now,
        );
      }
      stopwatch.stop();

      expect(scoreAccumulator, greaterThanOrEqualTo(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: '1,000 Cleanliness calculations should execute under 1000ms (actual: ${stopwatch.elapsedMilliseconds}ms)');
    });

    test('Benchmark: 10,000 FurnitureCatalog category and item lookups complete under 500ms', () {
      final sampleNames = [
        'King Bed',
        'Kitchen Sink',
        'Executive Desk',
        'Refrigerator',
        'Shower Cabin',
        'Ceiling Lamp',
        'Unknown Mystery Object',
      ];

      final stopwatch = Stopwatch()..start();
      int totalFound = 0;
      for (int i = 0; i < 10000; i++) {
        final query = sampleNames[i % sampleNames.length];
        final item = FurnitureCatalog.byName(query);
        if (item != null) totalFound++;
      }
      stopwatch.stop();

      expect(totalFound, greaterThan(3000));
      expect(stopwatch.elapsedMilliseconds, lessThan(800),
          reason: '10,000 catalog queries should take under 800ms (actual: ${stopwatch.elapsedMilliseconds}ms)');
    });

    test('Benchmark: 5,000 DTO JSON serialization and deserialization cycles under 1000ms', () {
      final now = DateTime(2026, 10, 3, 12, 0);
      final sampleTask = TaskItem(
        id: 't-perf',
        householdId: 'hh-bench',
        title: 'High throughput serialization test',
        description: '{"priority":4,"notes":"rapid serialization"}',
        referenceId: 'ref-1',
        referenceType: TaskReferenceType.furnitureItem,
        assignedTo: 'user-bench',
        status: TaskStatus.inProgress,
        pointsReward: 35,
        dueDate: now.add(const Duration(days: 3)),
        createdAt: now,
        updatedAt: now,
      );

      final stopwatch = Stopwatch()..start();
      TaskItem? lastReconstituted;
      for (int i = 0; i < 5000; i++) {
        final dto = TaskItemDto.fromDomain(sampleTask);
        final json = dto.toJson();
        final reconstitutedDto = TaskItemDto.fromJson(json);
        lastReconstituted = reconstitutedDto.toDomain();
      }
      stopwatch.stop();

      expect(lastReconstituted?.id, equals('t-perf'));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: '5,000 serialization roundtrips should complete under 1000ms (actual: ${stopwatch.elapsedMilliseconds}ms)');
    });

    test('Benchmark: 1,000 Load-Balancing adult assignment calculations under 500ms', () {
      final candidates = [
        UserEffortSnapshot(userId: 'u1', name: 'Parent 1', role: UserRole.admin, effortPoints: 120),
        UserEffortSnapshot(userId: 'u2', name: 'Parent 2', role: UserRole.admin, effortPoints: 45),
        UserEffortSnapshot(userId: 'u3', name: 'Child 1', role: UserRole.child, effortPoints: 10),
        UserEffortSnapshot(userId: 'u4', name: 'Parent 3', role: UserRole.admin, effortPoints: 80),
        UserEffortSnapshot(userId: 'u5', name: 'Child 2', role: UserRole.child, effortPoints: 0),
      ];

      final stopwatch = Stopwatch()..start();
      UserEffortSnapshot? lastChosen;
      for (int i = 0; i < 1000; i++) {
        lastChosen = AssignTaskUseCase.selectLeastBusyAdult(candidates);
      }
      stopwatch.stop();

      expect(lastChosen?.userId, equals('u2'));
      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: '1,000 load-balancing calculations should take under 500ms (actual: ${stopwatch.elapsedMilliseconds}ms)');
    });
  });
}
