import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connection/connection.dart';

part 'app_database.g.dart';

/// 1. Háztartások tábla (Household)
class HouseholdsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 2. Felhasználók tábla (User: admin / child)
class UsersTable extends Table {
  TextColumn get id => text()();
  TextColumn get householdId => text()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get role => text()(); // 'admin' vagy 'child'
  TextColumn get avatarUrl => text().nullable()();
  IntColumn get pointsTotal => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 3. Szobák tábla (Room: polygon_coordinates JSON, cleanliness_score)
class RoomsTable extends Table {
  TextColumn get id => text()();
  TextColumn get householdId => text()();
  TextColumn get name => text()();
  IntColumn get floor => integer().withDefault(const Constant(1))();
  TextColumn get polygonCoordinates => text().withDefault(const Constant('[]'))(); // JSON formátumban
  IntColumn get cleanlinessScore => integer().withDefault(const Constant(100))(); // 0-100
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isPendingSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 4. Bútorok és berendezési tárgyak tábla (Furniture_Item)
class FurnitureItemsTable extends Table {
  TextColumn get id => text()();
  TextColumn get roomId => text()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  TextColumn get positionCoordinates => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isPendingSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 5. Polimorf Feladatok tábla (Task)
class TasksTable extends Table {
  TextColumn get id => text()();
  TextColumn get householdId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  // Polimorf kapcsolat:
  TextColumn get referenceId => text()(); // Room.id vagy Furniture_Item.id
  TextColumn get referenceType => text()(); // 'Room' vagy 'Furniture_Item'
  TextColumn get assignedTo => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, in_progress, completed, verified
  IntColumn get pointsReward => integer().withDefault(const Constant(10))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isPendingSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 6. Offline Szinkronizációs Várósor (Sync Outbox Queue)
class SyncQueueTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get targetTable => text()(); // 'Room', 'Task', 'Furniture_Item'
  TextColumn get recordId => text()();
  TextColumn get operation => text()(); // 'INSERT', 'UPDATE', 'DELETE'
  TextColumn get payload => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [
  HouseholdsTable,
  UsersTable,
  RoomsTable,
  FurnitureItemsTable,
  TasksTable,
  SyncQueueTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Egyszerű migráció fejlesztési szakaszban
          for (final table in allTables) {
            await m.deleteTable(table.actualTableName);
            await m.createTable(table);
          }
        },
      );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
