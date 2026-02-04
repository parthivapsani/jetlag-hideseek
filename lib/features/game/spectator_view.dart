import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../app/theme.dart';
import 'game_map.dart';

class SpectatorView extends ConsumerStatefulWidget {
  final String sessionId;

  const SpectatorView({super.key, required this.sessionId});

  @override
  ConsumerState<SpectatorView> createState() => _SpectatorViewState();
}

class _SpectatorViewState extends ConsumerState<SpectatorView> {
  @override
  void initState() {
    super.initState();
    ref.read(currentSessionIdProvider.notifier).state = widget.sessionId;
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(currentSessionProvider);
    final timerState = ref.watch(timerProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
      data: (session) {
        if (session == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Game not found'),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            ),
          );
        }

        // Check if game ended
        if (session.status == SessionStatus.ended) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/game/${widget.sessionId}/over');
          });
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(session, timerState),
                Expanded(
                  child: Stack(
                    children: [
                      const GameMap(
                        showHiderZone: false,
                        showSeekerLocations: true,
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: _buildStatusCard(session),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(GameSession session, TimerState timerState) {
    final formattedTime = ref.watch(formattedRemainingTimeProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[800],
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPECTATOR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Watching the game',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formattedTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () async {
              await ref.read(gameActionsProvider).leaveSession();
              if (mounted) context.go('/');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(GameSession session) {
    final participants = ref.watch(participantsProvider).valueOrNull ?? [];
    final questionsAsync = ref.watch(sessionQuestionsProvider);
    final hider = ref.watch(hiderProvider);
    final seekers = ref.watch(seekersProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(session.status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(session.status),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),

            // Players
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hider',
                        style: TextStyle(
                          color: JetLagTheme.hiderGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(hider?.displayName ?? 'None'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seekers',
                        style: TextStyle(
                          color: JetLagTheme.seekerRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        seekers.isEmpty
                            ? 'None'
                            : seekers.map((s) => s.displayName).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Question count
            questionsAsync.whenData((questions) {
              return Text(
                'Questions asked: ${questions.where((q) => !q.wasTestMode).length}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              );
            }).valueOrNull ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.waiting:
        return Colors.grey;
      case SessionStatus.hiding:
        return Colors.orange;
      case SessionStatus.seeking:
        return JetLagTheme.seekerRed;
      case SessionStatus.paused:
        return Colors.blue;
      case SessionStatus.ended:
        return Colors.purple;
    }
  }

  String _getStatusText(SessionStatus status) {
    switch (status) {
      case SessionStatus.waiting:
        return 'Waiting to Start';
      case SessionStatus.hiding:
        return 'Hiding Period';
      case SessionStatus.seeking:
        return 'Seeking in Progress';
      case SessionStatus.paused:
        return 'Game Paused';
      case SessionStatus.ended:
        return 'Game Over';
    }
  }
}
