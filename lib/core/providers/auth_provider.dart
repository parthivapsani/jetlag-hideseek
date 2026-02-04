import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((event) => event.session?.user);
});

// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

// Device token provider (for anonymous identification)
final deviceTokenProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var token = prefs.getString('device_token');
  if (token == null) {
    token = const Uuid().v4();
    await prefs.setString('device_token', token);
  }
  return token;
});

// Display name provider
final displayNameProvider =
    StateNotifierProvider<DisplayNameNotifier, String?>((ref) {
  return DisplayNameNotifier();
});

class DisplayNameNotifier extends StateNotifier<String?> {
  DisplayNameNotifier() : super(null) {
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('display_name');
  }

  Future<void> setDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_name', name);
    state = name;
  }
}

// Auth actions provider
final authActionsProvider = Provider<AuthActions>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthActions(client);
});

class AuthActions {
  final SupabaseClient _client;

  AuthActions(this._client);

  Future<AuthResponse> signInAnonymously() async {
    return await _client.auth.signInAnonymously();
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
