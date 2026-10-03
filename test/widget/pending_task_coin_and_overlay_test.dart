import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/floor_plan/pending_task_coin.dart';
import 'package:spatio_cleaning/core/widgets/task_celebration_overlay.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/task_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AnimatedCoin renders correctly and responds to tap', (WidgetTester tester) async {
    final task = TaskItem(
      id: 't-pending-coin',
      householdId: 'hh-1',
      title: 'Sweep Front Porch',
      referenceId: 'r-1',
      referenceType: TaskReferenceType.room,
      status: TaskStatus.pendingApproval,
      pointsReward: 20,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    bool wasTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              AnimatedCoin(
                task: task,
                screenPosition: const Offset(100.0, 100.0),
                onTap: () {
                  wasTapped = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify AnimatedCoin exists
    expect(find.byType(AnimatedCoin), findsOneWidget);

    // Tap on the coin
    await tester.tap(find.byType(AnimatedCoin));
    await tester.pump();

    expect(wasTapped, isTrue);
  });

  testWidgets('TaskCelebrationOverlay renders points, streak, and title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TaskCelebrationOverlay(
            points: 50,
            taskTitle: 'Cleaned Garage',
            currentStreak: 5,
            currentPoints: 250,
            isLevelUp: true,
            newBadge: '🧹 Sweep Master',
          ),
        ),
      ),
    );

    // Run animation frames
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('+50 Points!'), findsOneWidget);
    expect(find.text('Cleaned Garage'), findsOneWidget);
    expect(find.text('LEVEL UP!'), findsOneWidget);
    expect(find.text('🎖️ Unlocked: 🧹 Sweep Master'), findsOneWidget);

    // Elapse auto-dismiss 2.6s timer
    await tester.pump(const Duration(milliseconds: 3000));
  });
}
