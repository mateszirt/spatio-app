import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

/// Initializes the Supabase client
Future<void> initializeSupabase() async {
  // If connecting to production Supabase project, provide keys in app_constants.dart
  if (AppConstants.supabaseUrl != 'https://your-project.supabase.co') {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      publishableKey: AppConstants.supabaseAnonKey,
    );
  }
}

/// Riverpod provider for accessing the Supabase client
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});
