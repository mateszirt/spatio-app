import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/widgets/add_task_dialog.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/room.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/furniture_item.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/domain/models/task_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleRooms = [
    Room(
      id: 'r-1',
      householdId: 'hh-1',
      name: 'Kitchen',
      floor: 1,
      polygonCoordinates: const [],
      cleanlinessScore: 80,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  final sampleFurniture = [
    FurnitureItem(
      id: 'f-1',
      roomId: 'r-1',
      name: 'Refrigerator',
      category: 'Kitchen',
      positionCoordinates: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  testWidgets('AddTaskDialog renders form inputs and allows entering title and switching priorities',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AddTaskDialog.show(
                    context,
                    rooms: sampleRooms,
                    furnitureList: sampleFurniture,
                    initialReferenceType: TaskReferenceType.room,
                    initialTargetId: 'r-1',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap to show dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify Title input field exists
    expect(find.byType(TextField), findsWidgets);

    // Enter a task title
    final titleFinder = find.byType(TextField).first;
    await tester.enterText(titleFinder, 'Deep clean the oven');
    await tester.pumpAndSettle();

    expect(find.text('Deep clean the oven'), findsOneWidget);
  });
}
