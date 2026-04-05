import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/services/supabase_init.dart';
import '../../design/widgets/widgets.dart';
import '../../design/theme.dart';

// Admin data providers
final _activeSessionsProvider =
    FutureProvider.autoDispose<List<GameSession>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  if (service == null) return [];
  final raw = await service.getActiveSessions();
  return raw.map((e) => GameSession.fromJson(e)).toList();
});

final _allSessionsProvider =
    FutureProvider.autoDispose<List<GameSession>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  if (service == null) return [];
  final raw = await service.getAllSessions();
  return raw.map((e) => GameSession.fromJson(e)).toList();
});

final _participantCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  if (service == null) return {};
  final counts = await service.getSessionParticipantCounts();
  return {for (final c in counts) c['session_id'] as String: c['count'] as int};
});

final _featureRequestsProvider =
    FutureProvider.autoDispose<List<FeatureRequest>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  if (service == null) return [];
  return service.getFeatureRequests();
});

final _gameAreasProvider =
    FutureProvider.autoDispose<List<GameArea>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  if (service == null) return [];
  return service.getGameAreas();
});

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  bool _isCreating = false;
  String? _createdRoomCode;
  String? _selectedAreaId;

  void _refresh() {
    ref.invalidate(_activeSessionsProvider);
    ref.invalidate(_allSessionsProvider);
    ref.invalidate(_participantCountsProvider);
    ref.invalidate(_featureRequestsProvider);
    ref.invalidate(_gameAreasProvider);
  }

  Future<void> _stopSession(String sessionId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    try {
      await service.stopSession(sessionId);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session stopped')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop session: $e')),
        );
      }
    }
  }

  Future<void> _createGame(String areaId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    setState(() => _isCreating = true);
    try {
      final session = await service.createSession(
        gameAreaId: areaId,
        hidingPeriodSeconds: 3600,
        zoneRadiusMeters: 804.672,
        createdBy: 'admin',
      );
      setState(() {
        _createdRoomCode = session.roomCode;
        _isCreating = false;
      });
      _refresh();
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create game: $e')),
        );
      }
    }
  }

  Future<void> _updateFeatureStatus(String id, String status) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    try {
      await service.updateFeatureRequestStatus(id, status);
      ref.invalidate(_featureRequestsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSessions = ref.watch(_activeSessionsProvider);
    final allSessions = ref.watch(_allSessionsProvider);
    final counts = ref.watch(_participantCountsProvider);
    final featureRequests = ref.watch(_featureRequestsProvider);
    final gameAreas = ref.watch(_gameAreasProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Jet Lag Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ======= Active Games =======
          _SectionHeader(title: 'Active Games', icon: Icons.play_circle_outline),
          const SizedBox(height: 12),
          activeSessions.when(
            loading: () => const _LoadingWidget(),
            error: (e, _) => _ErrorWidget(error: e.toString()),
            data: (sessions) {
              if (sessions.isEmpty) {
                return _EmptyWidget(message: 'No active games');
              }
              return Column(
                children: sessions.map((s) {
                  final playerCount = counts.maybeWhen(
                    data: (c) => c[s.id] ?? 0,
                    orElse: () => 0,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SessionCard(
                      session: s,
                      participantCount: playerCount,
                      onSpectate: () => context.go('/game/${s.id}/spectator'),
                      onStop: () => _stopSession(s.id),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 28),

          // ======= Create Game =======
          _SectionHeader(title: 'Create Game', icon: Icons.add_circle_outline),
          const SizedBox(height: 12),
          JetlagCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                gameAreas.when(
                  loading: () => const _LoadingWidget(),
                  error: (e, _) => _ErrorWidget(error: e.toString()),
                  data: (areas) {
                    if (areas.isEmpty) {
                      return Text(
                        'No game areas defined. Create one from the main app first.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedAreaId ?? areas.first.id,
                          decoration: const InputDecoration(
                            labelText: 'Game Area',
                          ),
                          items: areas
                              .map((a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(a.name),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedAreaId = v),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: JetlagButton(
                            label: 'Create Game',
                            icon: Icons.add,
                            isLoading: _isCreating,
                            onPressed: _isCreating
                                ? null
                                : () {
                                    final areaId = _selectedAreaId ??
                                        (areas.isNotEmpty ? areas.first.id : null);
                                    if (areaId != null) _createGame(areaId);
                                  },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (_createdRoomCode != null) ...[
                  const SizedBox(height: 16),
                  JetlagCard(
                    borderColor: context.green,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Game Created!',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: context.green),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                'jetlag.ratz.fyi/g/$_createdRoomCode',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                              text: 'https://jetlag.ratz.fyi/g/$_createdRoomCode',
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Link copied')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ======= Feature Requests =======
          _SectionHeader(title: 'Feature Requests', icon: Icons.lightbulb_outline),
          const SizedBox(height: 12),
          featureRequests.when(
            loading: () => const _LoadingWidget(),
            error: (e, _) => _ErrorWidget(error: e.toString()),
            data: (requests) {
              if (requests.isEmpty) {
                return _EmptyWidget(message: 'No feature requests');
              }
              return Column(
                children: requests.map((r) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FeatureRequestAdminCard(
                      request: r,
                      onStatusChange: (status) =>
                          _updateFeatureStatus(r.id, status),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 28),

          // ======= Previous Games =======
          _SectionHeader(title: 'Previous Games', icon: Icons.history),
          const SizedBox(height: 12),
          allSessions.when(
            loading: () => const _LoadingWidget(),
            error: (e, _) => _ErrorWidget(error: e.toString()),
            data: (sessions) {
              final ended = sessions
                  .where((s) => s.status == SessionStatus.ended)
                  .toList();
              if (ended.isEmpty) {
                return _EmptyWidget(message: 'No previous games');
              }
              return Column(
                children: ended.map((s) {
                  final playerCount = counts.maybeWhen(
                    data: (c) => c[s.id] ?? 0,
                    orElse: () => 0,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _EndedSessionCard(
                      session: s,
                      participantCount: playerCount,
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ============ Helper Widgets ============

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.accent),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ],
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String error;
  const _ErrorWidget({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Error: $error', style: TextStyle(color: context.red)),
      ),
    );
  }
}

class _EmptyWidget extends StatelessWidget {
  final String message;
  const _EmptyWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return JetlagCard(
      child: Center(
        child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final GameSession session;
  final int participantCount;
  final VoidCallback onSpectate;
  final VoidCallback onStop;

  const _SessionCard({
    required this.session,
    required this.participantCount,
    required this.onSpectate,
    required this.onStop,
  });

  JetlagBadgeColor _statusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.waiting:
        return JetlagBadgeColor.blue;
      case SessionStatus.hiding:
        return JetlagBadgeColor.orange;
      case SessionStatus.seeking:
        return JetlagBadgeColor.red;
      case SessionStatus.paused:
        return JetlagBadgeColor.purple;
      case SessionStatus.ended:
        return JetlagBadgeColor.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return JetlagCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  session.roomCode,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                ),
              ),
              JetlagBadge(
                label: session.status.name,
                color: _statusColor(session.status),
                showPulse: session.status != SessionStatus.ended &&
                    session.status != SessionStatus.waiting,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$participantCount players  \u2022  ${_relativeTime(session.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              JetlagButton(
                label: 'Spectate',
                icon: Icons.visibility,
                variant: JetlagButtonVariant.secondary,
                onPressed: onSpectate,
              ),
              const SizedBox(width: 8),
              JetlagButton(
                label: 'Stop',
                icon: Icons.stop,
                variant: JetlagButtonVariant.danger,
                onPressed: onStop,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EndedSessionCard extends StatelessWidget {
  final GameSession session;
  final int participantCount;

  const _EndedSessionCard({
    required this.session,
    required this.participantCount,
  });

  @override
  Widget build(BuildContext context) {
    return JetlagCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.roomCode,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                ),
              ),
              JetlagBadge(
                label: 'Ended',
                color: JetlagBadgeColor.green,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              '$participantCount players',
              if (session.winningTeamId != null) 'Winner: ${session.winningTeamId}',
              if (session.endedAt != null) 'Ended ${_relativeTime(session.endedAt!)}',
            ].join('  \u2022  '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FeatureRequestAdminCard extends StatelessWidget {
  final FeatureRequest request;
  final void Function(String status) onStatusChange;

  const _FeatureRequestAdminCard({
    required this.request,
    required this.onStatusChange,
  });

  JetlagBadgeColor _badgeColor(FeatureRequestStatus status) {
    switch (status) {
      case FeatureRequestStatus.open:
        return JetlagBadgeColor.blue;
      case FeatureRequestStatus.inProgress:
        return JetlagBadgeColor.orange;
      case FeatureRequestStatus.done:
        return JetlagBadgeColor.green;
    }
  }

  String _statusLabel(FeatureRequestStatus status) {
    switch (status) {
      case FeatureRequestStatus.open:
        return 'Open';
      case FeatureRequestStatus.inProgress:
        return 'In Progress';
      case FeatureRequestStatus.done:
        return 'Done';
    }
  }

  @override
  Widget build(BuildContext context) {
    return JetlagCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 8),
              JetlagBadge(
                label: _statusLabel(request.status),
                color: _badgeColor(request.status),
              ),
            ],
          ),
          if (request.description != null &&
              request.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            [
              if (request.submitterName != null) request.submitterName!,
              _relativeTime(request.createdAt ?? DateTime.now()),
            ].where((s) => s.isNotEmpty).join(' \u2022 '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (request.status != FeatureRequestStatus.open)
                JetlagButton(
                  label: 'Open',
                  variant: JetlagButtonVariant.secondary,
                  onPressed: () => onStatusChange('open'),
                ),
              if (request.status != FeatureRequestStatus.inProgress)
                JetlagButton(
                  label: 'In Progress',
                  variant: JetlagButtonVariant.secondary,
                  icon: Icons.pending,
                  onPressed: () => onStatusChange('in_progress'),
                ),
              if (request.status != FeatureRequestStatus.done)
                JetlagButton(
                  label: 'Done',
                  variant: JetlagButtonVariant.primary,
                  icon: Icons.check,
                  onPressed: () => onStatusChange('done'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inDays > 365) return '${diff.inDays ~/ 365}y ago';
  if (diff.inDays > 30) return '${diff.inDays ~/ 30}mo ago';
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'just now';
}
