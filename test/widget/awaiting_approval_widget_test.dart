import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spatio_cleaning/core/services/auth_service.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/controllers/household_state_provider.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/screens/awaiting_household_approval_screen.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/screens/household_screen.dart';

class MockAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  MockAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class MockCurrentUserNotifier extends CurrentUserNotifier {
  final FamilyMember? _initial;
  MockCurrentUserNotifier(this._initial);

  @override
  FamilyMember? build() => _initial;
}

class MockHouseholdMembersNotifier extends HouseholdMembersNotifier {
  final List<FamilyMember> _initial;
  MockHouseholdMembersNotifier(this._initial);

  @override
  List<FamilyMember> build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AwaitingHouseholdApprovalScreen renders pending message and action buttons',
      (WidgetTester tester) async {
    const pendingState = AuthState(
      isAuthenticated: true,
      userId: 'user-child-1',
      name: 'Oliver',
      email: 'oliver@test.com',
      householdName: 'Szabó Family',
      membershipStatus: 'pending',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => MockAuthNotifier(pendingState)),
        ],
        child: const MaterialApp(
          home: AwaitingHouseholdApprovalScreen(),
        ),
      ),
    );

    expect(find.text('Csatlakozási kérelem elküldve!'), findsOneWidget);
    expect(find.textContaining('Szabó Family'), findsOneWidget);
    expect(find.text('Állapot ellenőrzése'), findsOneWidget);
    expect(find.text('Kijelentkezés / Másik fiók'), findsOneWidget);
  });

  testWidgets('HouseholdScreen displays Pending Join Requests for parent admin',
      (WidgetTester tester) async {
    const parentUser = FamilyMember(
      id: 'p-1',
      name: 'Anya',
      role: 'parent',
      avatar: '👩‍💼',
      email: 'anya@test.com',
      membershipStatus: 'active',
    );

    const pendingChild = FamilyMember(
      id: 'c-1',
      name: 'Oliver',
      role: 'child',
      avatar: '👦',
      email: 'oliver@test.com',
      membershipStatus: 'pending',
    );

    const authState = AuthState(
      isAuthenticated: true,
      userId: 'p-1',
      name: 'Anya',
      householdName: 'Happy Family',
      inviteCode: 'SPATIO-7K9M-X4WP',
      role: 'parent',
      membershipStatus: 'active',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => MockAuthNotifier(authState)),
          currentUserProvider.overrideWith(() => MockCurrentUserNotifier(parentUser)),
          householdMembersProvider.overrideWith(
            () => MockHouseholdMembersNotifier([parentUser, pendingChild]),
          ),
        ],
        child: const MaterialApp(
          home: HouseholdScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Pending Join Requests'), findsOneWidget);
    expect(find.text('Oliver'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });
}
