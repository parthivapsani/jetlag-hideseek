import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Helper to get/set the participant ID for a specific game session from localStorage.
/// Key format: jetlag_participant_{nanoid}
class GameParticipantStorage {
  static Future<String?> getParticipantId(String gameCode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jetlag_participant_$gameCode');
  }

  static Future<void> setParticipantId(String gameCode, String participantId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jetlag_participant_$gameCode', participantId);
  }

  static Future<void> removeParticipantId(String gameCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jetlag_participant_$gameCode');
  }
}
