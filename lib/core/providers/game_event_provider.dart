import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'game_provider.dart';

/// All events for a session (for replay/summary).
final sessionEventsProvider =
    FutureProvider.family<List<GameEvent>, String>((ref, sessionId) async {
  final service = ref.watch(supabaseServiceProvider);
  if (service == null) return [];
  final raw = await service.getSessionEvents(sessionId);
  return raw.map((e) => GameEvent.fromJson(e)).toList();
});

/// Stream of events for the current session via Supabase Realtime.
final gameEventsStreamProvider = StreamProvider<List<GameEvent>>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  final client = ref.watch(supabaseClientProvider);
  if (sessionId == null || client == null) return const Stream.empty();

  return client
      .from('game_events')
      .stream(primaryKey: ['id'])
      .eq('session_id', sessionId)
      .order('created_at')
      .map((rows) => rows.map((e) => GameEvent.fromJson(_eventFromDb(e))).toList());
});

/// Helper to log events without blocking game flow.
class EventLogger {
  final Ref _ref;
  EventLogger(this._ref);

  Future<void> log({
    required String eventType,
    String? roundId,
    Map<String, dynamic> payload = const {},
  }) async {
    final service = _ref.read(supabaseServiceProvider);
    final sessionId = _ref.read(currentSessionIdProvider);
    if (service == null || sessionId == null) return;

    // Fire and forget — don't block game actions on event logging
    service.logEvent(
      sessionId: sessionId,
      roundId: roundId,
      eventType: eventType,
      payload: payload,
    );
  }
}

final eventLoggerProvider = Provider<EventLogger>((ref) => EventLogger(ref));

Map<String, dynamic> _eventFromDb(Map<String, dynamic> data) {
  return {
    'id': data['id'],
    'sessionId': data['session_id'],
    'roundId': data['round_id'],
    'eventType': data['event_type'],
    'payload': data['payload'] ?? {},
    'createdAt': data['created_at'],
  };
}
