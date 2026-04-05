import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/round.dart';
import '../services/supabase_init.dart';
import 'game_provider.dart';

/// All rounds for the current session.
final roundsProvider = StreamProvider<List<Round>>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  final client = ref.watch(supabaseClientProvider);
  if (sessionId == null || client == null) return const Stream.empty();

  return client
      .from('rounds')
      .stream(primaryKey: ['id'])
      .eq('session_id', sessionId)
      .order('round_number')
      .map((rows) => rows.map((e) => Round.fromJson(_roundFromDb(e))).toList());
});

/// The currently active round (not 'found').
final activeRoundProvider = Provider<Round?>((ref) {
  final rounds = ref.watch(roundsProvider).valueOrNull ?? [];
  try {
    return rounds.lastWhere((r) => r.status != RoundStatus.found);
  } catch (_) {
    return null;
  }
});

/// Current round number.
final currentRoundNumberProvider = Provider<int>((ref) {
  final round = ref.watch(activeRoundProvider);
  return round?.roundNumber ?? 0;
});

class RoundActions {
  final Ref ref;
  RoundActions(this.ref);

  Future<Round?> startRound({
    required String sessionId,
    required int roundNumber,
    required String hiderTeamId,
    required String seekerTeamId,
  }) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return null;
    return service.createRound(
      sessionId: sessionId,
      roundNumber: roundNumber,
      hiderTeamId: hiderTeamId,
      seekerTeamId: seekerTeamId,
    );
  }

  Future<void> startHiding(String roundId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.updateRoundStatus(roundId, 'hiding',
        hidingStartedAt: DateTime.now());
  }

  Future<void> startSeeking(String roundId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.updateRoundStatus(roundId, 'seeking',
        seekingStartedAt: DateTime.now());
  }

  Future<void> enterEndgame(String roundId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.updateRoundStatus(roundId, 'endgame');
  }

  Future<void> markFound(String roundId, int hideDurationSeconds) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.updateRoundStatus(
      roundId,
      'found',
      foundAt: DateTime.now(),
      hideDurationSeconds: hideDurationSeconds,
    );
  }

  Future<void> pauseRound(String roundId, int remainingSeconds) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.updateRoundStatus(
      roundId,
      'seeking',
      timerPausedAt: DateTime.now(),
      pausedTimeRemainingSeconds: remainingSeconds,
    );
  }

  Future<void> resumeRound(String roundId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.updateRoundStatus(roundId, 'seeking');
  }

  /// Determine overall winner based on longest hide time.
  Future<void> determineWinner(String sessionId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    final rounds = await service.getRounds(sessionId);
    final completed = rounds
        .where(
            (r) => r.status == RoundStatus.found && r.hideDurationSeconds != null)
        .toList();
    if (completed.isEmpty) return;

    final hideTimes = <String, int>{};
    for (final round in completed) {
      if (round.hiderTeamId != null) {
        hideTimes[round.hiderTeamId!] =
            (hideTimes[round.hiderTeamId!] ?? 0) + round.hideDurationSeconds!;
      }
    }

    final winnerEntry =
        hideTimes.entries.reduce((a, b) => a.value > b.value ? a : b);
    await service.setSessionWinner(sessionId, winnerEntry.key);
  }
}

final roundActionsProvider = Provider((ref) => RoundActions(ref));

Map<String, dynamic> _roundFromDb(Map<String, dynamic> data) {
  return {
    'id': data['id'],
    'sessionId': data['session_id'],
    'roundNumber': data['round_number'],
    'hiderTeamId': data['hider_team_id'],
    'seekerTeamId': data['seeker_team_id'],
    'status': data['status'],
    'hidingStartedAt': data['hiding_started_at'],
    'seekingStartedAt': data['seeking_started_at'],
    'timerPausedAt': data['timer_paused_at'],
    'pausedTimeRemainingSeconds': data['paused_time_remaining_seconds'],
    'foundAt': data['found_at'],
    'hideDurationSeconds': data['hide_duration_seconds'],
    'createdAt': data['created_at'],
  };
}
