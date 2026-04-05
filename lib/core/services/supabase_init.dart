import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Supabase configuration
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jetlag.ratz.fyi/supabase',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNjQxNzY5MjAwLCJleHAiOjE3OTk1MzU2MDB9.hVGT3I0Nxn2dz0Tdh9HWlxu_a0HUodMXm6PSuTFGct0',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty && !url.contains('placeholder');
}

/// Initialize Supabase
Future<void> initializeSupabase() async {
  if (!SupabaseConfig.isConfigured) {
    debugPrint('Supabase not configured. Running in offline mode.');
    debugPrint('   Set SUPABASE_URL and SUPABASE_ANON_KEY environment variables.');
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  debugPrint('Supabase initialized');
}

/// Provider for Supabase client
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  return Supabase.instance.client;
});

/// Provider for Supabase service
final supabaseServiceProvider = Provider<SupabaseService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return SupabaseService(client);
});

/// Check if running in offline mode (no Supabase)
final isOfflineModeProvider = Provider<bool>((ref) {
  return !SupabaseConfig.isConfigured;
});
