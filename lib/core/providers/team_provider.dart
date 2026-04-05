import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'game_provider.dart';

// ============ Teams ============

final teamsProvider = StreamProvider<List<Team>>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) return Stream.value([]);

  final client = ref.watch(supabaseClientProvider);
  if (client == null) return Stream.value([]);

  return client
      .from('teams')
      .stream(primaryKey: ['id'])
      .eq('session_id', sessionId)
      .order('display_order')
      .map((rows) => rows.map(_teamFromDb).toList());
});

/// True when every team has at least 1 player and the counts are within 1.
final teamsBalancedProvider = Provider<bool>((ref) {
  final teams = ref.watch(teamsProvider).valueOrNull ?? [];
  final participants = ref.watch(participantsProvider).valueOrNull ?? [];

  if (teams.length < 2) return false;

  final counts = <String, int>{};
  for (final t in teams) {
    counts[t.id] = 0;
  }
  for (final p in participants) {
    if (p.teamId != null && counts.containsKey(p.teamId)) {
      counts[p.teamId!] = (counts[p.teamId!] ?? 0) + 1;
    }
  }

  // Each team needs at least 1 member
  if (counts.values.any((c) => c < 1)) return false;

  // Counts must be within 1 of each other
  final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
  final minCount = counts.values.reduce((a, b) => a < b ? a : b);
  return (maxCount - minCount) <= 1;
});

// ============ Team Actions ============

class TeamActions {
  final Ref _ref;
  final SupabaseService _service;

  TeamActions(this._ref, this._service);

  Future<void> createDefaultTeams(String sessionId) async {
    final client = _service.client;
    await client.from('teams').insert([
      {
        'session_id': sessionId,
        'name': 'Team Alpha',
        'color': 'green',
        'display_order': 0,
      },
      {
        'session_id': sessionId,
        'name': 'Team Beta',
        'color': 'red',
        'display_order': 1,
      },
    ]);
  }

  Future<void> switchTeam(String participantId, String teamId) async {
    await _service.updateParticipantTeam(participantId, teamId);
  }
}

final teamActionsProvider = Provider<TeamActions?>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  if (service == null) return null;
  return TeamActions(ref, service);
});

// ============ Helpers ============

Team _teamFromDb(Map<String, dynamic> data) {
  return Team(
    id: data['id'] as String,
    sessionId: data['session_id'] as String,
    name: data['name'] as String,
    color: (data['color'] as String?) ?? 'green',
    displayOrder: (data['display_order'] as int?) ?? 0,
    createdAt: data['created_at'] != null
        ? DateTime.parse(data['created_at'] as String)
        : null,
  );
}
