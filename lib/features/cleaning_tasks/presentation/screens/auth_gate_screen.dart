import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_service.dart';
import 'awaiting_household_approval_screen.dart';
import 'cleaning_dashboard_screen.dart';
import 'login_screen.dart';

class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.isAuthenticated) {
      if (authState.isPendingApproval) {
        return const AwaitingHouseholdApprovalScreen();
      }
      return const CleaningDashboardScreen();
    }

    return const LoginScreen();
  }
}
