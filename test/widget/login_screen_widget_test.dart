import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spatio_cleaning/core/constants/app_strings.dart';
import 'package:spatio_cleaning/features/cleaning_tasks/presentation/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createLoginScreen() {
    return const ProviderScope(
      child: MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  tearDown(() {
    FocusManager.instance.primaryFocus?.unfocus();
  });

  testWidgets('LoginScreen renders email, password inputs and reacts to text entry in Sign In mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(createLoginScreen());
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsWidgets);

    // Enter email
    await tester.enterText(textFields.at(0), 'family@example.com');
    await tester.pumpAndSettle();

    // Enter password
    await tester.enterText(textFields.at(1), 'Secret123');
    await tester.pumpAndSettle();

    expect(find.text('family@example.com'), findsOneWidget);
    expect(find.text('Secret123'), findsOneWidget);

    // Toggle password visibility
    final visibilityIcon = find.byIcon(Icons.visibility_outlined);
    expect(visibilityIcon, findsOneWidget);
    await tester.tap(visibilityIcon);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    // Unfocus before finishing test to prevent orphaned FocusNode notifications
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
  });

  testWidgets('LoginScreen switches to Sign Up mode and renders live email & password validation criteria',
      (WidgetTester tester) async {
    await tester.pumpWidget(createLoginScreen());
    await tester.pumpAndSettle();

    // Switch to Sign Up tab (AppStrings.signUp: 'Create Account')
    final signUpTab = find.text(AppStrings.signUp);
    expect(signUpTab, findsOneWidget);
    await tester.tap(signUpTab);
    await tester.pumpAndSettle();

    // In Sign Up mode, extra fields like Name and Role selector should be present
    expect(find.text(AppStrings.roleParent), findsOneWidget);
    expect(find.text(AppStrings.roleChild), findsOneWidget);
    expect(find.text('Password requirements:'), findsOneWidget);
    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(find.text('At least one uppercase letter (A-Z)'), findsOneWidget);
    expect(find.text('At least one number (0-9)'), findsOneWidget);

    // In Sign Up mode:
    // Field 0: Name
    // Field 1: Household Name (or Invite Code)
    // Field 2: Email
    // Field 3: Password
    final textFields = find.byType(TextField);
    expect(textFields, findsAtLeast(4));

    // Test invalid email triggers live warning
    final emailField = textFields.at(2);
    await tester.enterText(emailField, 'not-an-email');
    await tester.pumpAndSettle();
    expect(find.text('Please enter a valid email address (e.g. name@domain.com)'), findsOneWidget);

    // Test valid email clears warning
    await tester.enterText(emailField, 'valid.user@example.com');
    await tester.pumpAndSettle();
    expect(find.text('Please enter a valid email address (e.g. name@domain.com)'), findsNothing);

    // Test live password validation
    final passwordField = textFields.at(3);

    // 1. Weak password (only lowercase, short)
    await tester.enterText(passwordField, 'short');
    await tester.pumpAndSettle();
    expect(find.text('Password requirements:'), findsOneWidget);

    // 2. Strong password satisfying all criteria (>= 8 chars, 1 uppercase, 1 digit)
    await tester.enterText(passwordField, 'Password123');
    await tester.pumpAndSettle();
    expect(find.text('Password123'), findsOneWidget);

    // Test Role selection switch
    await tester.tap(find.text(AppStrings.roleChild));
    await tester.pumpAndSettle();
    expect(find.text("Enter Parent's Invite Code (e.g. SPATIO-1)"), findsOneWidget);

    // Unfocus before finishing test
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
  });
}
