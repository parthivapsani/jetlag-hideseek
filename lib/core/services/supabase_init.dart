import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Supabase configuration
/// Replace these with your actual Supabase project credentials
class SupabaseConfig {
  // TODO: Move these to environment variables or secure storage
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key',
  );

  /// Check if Supabase is configured
  static bool get isConfigured =>
      url != 'https://your-project.supabase.co' && anonKey != 'your-anon-key';
}

/// Initialize Supabase
Future<void> initializeSupabase() async {
  if (!SupabaseConfig.isConfigured) {
    debugPrint('⚠️ Supabase not configured. Running in offline mode.');
    debugPrint('   Set SUPABASE_URL and SUPABASE_ANON_KEY environment variables.');
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  debugPrint('✅ Supabase initialized');
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

/// Provider for auth state
final supabaseAuthStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return Stream.value(AuthState(AuthChangeEvent.signedOut, null));
  }
  return client.auth.onAuthStateChange;
});

/// Provider for current user
final supabaseUserProvider = Provider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client?.auth.currentUser;
});

/// Check if running in offline mode (no Supabase)
final isOfflineModeProvider = Provider<bool>((ref) {
  return !SupabaseConfig.isConfigured;
});
