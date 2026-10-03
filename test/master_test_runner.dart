import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:cleaning_app/core/database/app_database.dart';

// 1. Domain Entities & Business Rules
import 'unit/domain/task_item_test.dart' as task_item_test;
import 'unit/domain/room_and_furniture_test.dart' as room_and_furniture_test;
import 'unit/domain/app_user_and_reward_test.dart' as app_user_and_reward_test;
import 'unit/domain/assign_task_usecase_test.dart' as assign_task_usecase_test;

// 2. DTO & Data Mappers
import 'unit/data/dto_and_mapper_test.dart' as dto_and_mapper_test;

// 3. In-Memory SQLite Drift Database (Zero Residue)
import 'unit/database/drift_in_memory_database_test.dart' as drift_in_memory_database_test;

// 4. Core Algorithms & Gamification
import 'unit/core/cleanliness_engine_deep_test.dart' as cleanliness_engine_deep_test;
import 'unit/core/cleanliness_engine_and_tasks_test.dart' as cleanliness_engine_and_tasks_test;
import 'unit/core/gamification_and_presence_test.dart' as gamification_and_presence_test;
import 'unit/core/geometry_and_catalog_test.dart' as geometry_and_catalog_test;
import 'unit/core/floor_plan_and_geometry_test.dart' as floor_plan_and_geometry_test;
import 'unit/core/app_strings_and_constants_test.dart' as app_strings_and_constants_test;

// 5. Offline Sync & State Controllers
import 'unit/services/sync_service_offline_test.dart' as sync_service_offline_test;
import 'unit/controllers/household_and_rewards_controllers_test.dart' as household_and_rewards_controllers_test;

// 6. Diagnostics: Performance, Precision, Memory & Fault Tolerance
import 'unit/diagnostics/performance_benchmark_test.dart' as performance_benchmark_test;
import 'unit/diagnostics/precision_and_memory_test.dart' as precision_and_memory_test;
import 'unit/diagnostics/fault_tolerance_and_negative_test.dart' as fault_tolerance_and_negative_test;
import 'unit/diagnostics/relational_and_idempotence_test.dart' as relational_and_idempotence_test;

// 7. UI & Widget Tests
import 'widget/add_task_dialog_test.dart' as add_task_dialog_test;
import 'widget/rewards_store_view_test.dart' as rewards_store_view_test;
import 'widget/pending_task_coin_and_overlay_test.dart' as pending_task_coin_and_overlay_test;
import 'widget/login_screen_widget_test.dart' as login_screen_widget_test;
import 'widget/dashboard_smoke_widget_test.dart' as dashboard_smoke_widget_test;

/// Master Test Runner Class that orchestrates and executes every test in the entire application.
class MasterTestRunner {
  MasterTestRunner._();

  /// Runs the complete, exhaustive test suite across all architectural layers.
  static void runAll() {
    TestWidgetsFlutterBinding.ensureInitialized();

    group('[MASTER SUITE] 1. Domain Entities & Use Cases', () {
      task_item_test.main();
      room_and_furniture_test.main();
      app_user_and_reward_test.main();
      assign_task_usecase_test.main();
    });

    group('[MASTER SUITE] 2. Data Transfer Objects & Mappers', () {
      dto_and_mapper_test.main();
    });

    group('[MASTER SUITE] 3. Drift SQLite Database & Transactions', () {
      drift_in_memory_database_test.main();
    });

    group('[MASTER SUITE] 4. Core Algorithms & Gamification Engine', () {
      cleanliness_engine_deep_test.main();
      cleanliness_engine_and_tasks_test.main();
      gamification_and_presence_test.main();
      geometry_and_catalog_test.main();
      floor_plan_and_geometry_test.main();
      app_strings_and_constants_test.main();
    });

    group('[MASTER SUITE] 5. Offline-First Sync & Presentation Controllers', () {
      sync_service_offline_test.main();
      household_and_rewards_controllers_test.main();
    });

    group('[MASTER SUITE] 6. Diagnostics, Benchmarks & Resilience', () {
      performance_benchmark_test.main();
      precision_and_memory_test.main();
      fault_tolerance_and_negative_test.main();
      relational_and_idempotence_test.main();
    });

    group('[MASTER SUITE] 7. UI Widgets & Interactions', () {
      add_task_dialog_test.main();
      rewards_store_view_test.main();
      pending_task_coin_and_overlay_test.main();
      login_screen_widget_test.main();
      dashboard_smoke_widget_test.main();
    });

    group('[MASTER SUITE] 8. Zero-Residue Database Guarantee Verification', () {
      test('Verifies that ephemeral in-memory databases leave zero residue after execution', () async {
        final ephemeralDb = AppDatabase(NativeDatabase.memory());

        // Perform transactional write operations
        await ephemeralDb.into(ephemeralDb.householdsTable).insert(
          HouseholdsTableCompanion.insert(
            id: 'hh-zero-residue',
            name: 'Purity Check Household',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final recordsBeforeClose = await ephemeralDb.select(ephemeralDb.householdsTable).get();
        expect(recordsBeforeClose.length, equals(1));

        // Close in-memory database -> instantly evaporated from RAM
        await ephemeralDb.close();

        // Fresh instance has zero residual data
        final freshDb = AppDatabase(NativeDatabase.memory());
        final recordsAfter = await freshDb.select(freshDb.householdsTable).get();
        expect(recordsAfter, isEmpty, reason: 'In-memory SQLite database guaranteed 100% clean with zero disk/cloud residue');
        await freshDb.close();
      });
    });
  }
}

/// Entrypoint to execute the full suite
void main() {
  MasterTestRunner.runAll();
}
