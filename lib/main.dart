import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/network/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'features/cleaning_tasks/presentation/screens/auth_gate_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase client
  await initializeSupabase();

  runApp(
    const ProviderScope(
      child: SpatioApp(),
    ),
  );
}

class SpatioApp extends StatelessWidget {
  const SpatioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthGateScreen(),
    );
  }
}

/// Backwards compatibility alias
typedef CleaningApp = SpatioApp;
