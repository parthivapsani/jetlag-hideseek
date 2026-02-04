import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'auth_provider.dart';

// Service providers
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseService(client);
});

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return RealtimeService(client);
});

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() => service.dispose());
  return service;
});

final nominatimServiceProvider = Provider<NominatimService>((ref) {
  final service = NominatimService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ============ Game Areas ============

final gameAreasProvider = FutureProvider<List<GameArea>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.getGameAreas();
});

final gameAreaProvider =
    FutureProvider.family<GameArea?, String>((ref, id) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.getGameArea(id);
});

// ============ Current Session ============

final currentSessionIdProvider = StateProvider<String?>((ref) => null);

final currentSessionProvider = StreamProvider<GameSession?>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) return Stream.value(null);

  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);

  // Initial fetch + realtime updates
  return _sessionStream(service, realtime, sessionId);
});

Stream<GameSession?> _sessionStream(
  SupabaseService service,
  RealtimeService realtime,
  String sessionId,
) async* {
  // First emit the current state
  yield await service.getSession(sessionId);

  // Then emit updates
  yield* realtime.subscribeToSession(sessionId);
}

final currentParticipantIdProvider = StateProvider<String?>((ref) => null);

final currentParticipantProvider = Provider<Participant?>((ref) {
  final participantId = ref.watch(currentParticipantIdProvider);
  final participants = ref.watch(participantsProvider).valueOrNull ?? [];
  if (participantId == null) return null;
  return participants.where((p) => p.id == participantId).firstOrNull;
});

// ============ Participants ============

final participantsProvider = StreamProvider<List<Participant>>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) return Stream.value([]);

  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);

  return _participantsStream(service, realtime, sessionId);
});

Stream<List<Participant>> _participantsStream(
  SupabaseService service,
  RealtimeService realtime,
  String sessionId,
) async* {
  yield await service.getParticipants(sessionId);
  yield* realtime.subscribeToParticipants(sessionId);
}

final hiderProvider = Provider<Participant?>((ref) {
  final participants = ref.watch(participantsProvider).valueOrNull ?? [];
  return participants
      .where((p) => p.role == ParticipantRole.hider)
      .firstOrNull;
});

final seekersProvider = Provider<List<Participant>>((ref) {
  final participants = ref.watch(participantsProvider).valueOrNull ?? [];
  return participants.where((p) => p.role == ParticipantRole.seeker).toList();
});

// ============ Game Actions ============

final gameActionsProvider = Provider<GameActions>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);
  return GameActions(ref, service, realtime);
});

class GameActions {
  final Ref _ref;
  final SupabaseService _service;
  final RealtimeService _realtime;

  GameActions(this._ref, this._service, this._realtime);

  Future<GameSession> createSession({
    required String gameAreaId,
    required int hidingPeriodSeconds,
    required double zoneRadiusMeters,
  }) async {
    final deviceToken = await _ref.read(deviceTokenProvider.future);
    final session = await _service.createSession(
      gameAreaId: gameAreaId,
      hidingPeriodSeconds: hidingPeriodSeconds,
      zoneRadiusMeters: zoneRadiusMeters,
      createdBy: deviceToken,
    );
    _ref.read(currentSessionIdProvider.notifier).state = session.id;
    return session;
  }

  Future<GameSession?> joinSessionByCode(String roomCode) async {
    final session = await _service.getSessionByRoomCode(roomCode);
    if (session != null) {
      _ref.read(currentSessionIdProvider.notifier).state = session.id;
    }
    return session;
  }

  Future<Participant> joinAsParticipant({
    required String displayName,
    required ParticipantRole role,
    bool isHost = false,
  }) async {
    final sessionId = _ref.read(currentSessionIdProvider);
    if (sessionId == null) throw Exception('No active session');

    final deviceToken = await _ref.read(deviceTokenProvider.future);
    final user = _ref.read(currentUserProvider);

    final participant = await _service.joinSession(
      sessionId: sessionId,
      userId: user?.id,
      displayName: displayName,
      role: role,
      deviceToken: deviceToken,
      isHost: isHost,
    );

    _ref.read(currentParticipantIdProvider.notifier).state = participant.id;
    return participant;
  }

  Future<void> updateRole(ParticipantRole role) async {
    final participantId = _ref.read(currentParticipantIdProvider);
    if (participantId == null) return;
    await _service.updateParticipantRole(participantId, role);
  }

  Future<void> startHidingPeriod() async {
    final sessionId = _ref.read(currentSessionIdProvider);
    if (sessionId == null) return;
    await _service.updateSessionStatus(
      sessionId,
      SessionStatus.hiding,
      hidingStartedAt: DateTime.now(),
    );
  }

  Future<void> startSeeking() async {
    final sessionId = _ref.read(currentSessionIdProvider);
    if (sessionId == null) return;
    await _service.updateSessionStatus(
      sessionId,
      SessionStatus.seeking,
      seekingStartedAt: DateTime.now(),
    );
  }

  Future<void> pauseGame() async {
    final sessionId = _ref.read(currentSessionIdProvider);
    final session = _ref.read(currentSessionProvider).valueOrNull;
    if (sessionId == null || session == null) return;

    await _service.updateSessionStatus(
      sessionId,
      SessionStatus.paused,
      timerPausedAt: DateTime.now(),
      pausedTimeRemainingSeconds: session.remainingHidingTime?.inSeconds,
    );
  }

  Future<void> resumeGame() async {
    final sessionId = _ref.read(currentSessionIdProvider);
    final session = _ref.read(currentSessionProvider).valueOrNull;
    if (sessionId == null || session == null) return;

    final remainingSeconds = session.pausedTimeRemainingSeconds ?? 0;
    final newHidingStartedAt = DateTime.now().subtract(
      session.hidingPeriodDuration - Duration(seconds: remainingSeconds),
    );

    await _service.updateSessionStatus(
      sessionId,
      session.seekingStartedAt != null
          ? SessionStatus.seeking
          : SessionStatus.hiding,
      hidingStartedAt: newHidingStartedAt,
    );
  }

  Future<void> endGame({String? winnerId}) async {
    final sessionId = _ref.read(currentSessionIdProvider);
    if (sessionId == null) return;
    await _service.endSession(sessionId, winnerId: winnerId);
  }

  Future<void> leaveSession() async {
    final participantId = _ref.read(currentParticipantIdProvider);
    if (participantId != null) {
      await _service.leaveSession(participantId);
    }
    _ref.read(currentSessionIdProvider.notifier).state = null;
    _ref.read(currentParticipantIdProvider.notifier).state = null;
    _realtime.unsubscribeAll();
  }

  Future<void> updateLocation(double lat, double lng) async {
    final participantId = _ref.read(currentParticipantIdProvider);
    final sessionId = _ref.read(currentSessionIdProvider);
    if (participantId == null || sessionId == null) return;

    await _service.updateParticipantLocation(participantId, lat: lat, lng: lng);
    await _realtime.broadcastLocation(
      sessionId,
      participantId: participantId,
      lat: lat,
      lng: lng,
    );
  }
}

// ============ Game Area Actions ============

final gameAreaActionsProvider = Provider<GameAreaActions>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return GameAreaActions(ref, service);
});

class GameAreaActions {
  final Ref _ref;
  final SupabaseService _service;

  GameAreaActions(this._ref, this._service);

  Future<GameArea> saveGameArea(GameArea area) async {
    final created = await _service.createGameArea(area);
    _ref.invalidate(gameAreasProvider);
    return created;
  }

  Future<void> updateGameArea(GameArea area) async {
    await _service.updateGameArea(area);
    _ref.invalidate(gameAreasProvider);
  }

  Future<void> deleteGameArea(String id) async {
    await _service.deleteGameArea(id);
    _ref.invalidate(gameAreasProvider);
  }
}
