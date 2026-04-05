import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/widgets.dart';

class PostGameSummary extends ConsumerWidget {
  final String sessionId;

  const PostGameSummary({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ensure session ID is set
    final currentId = ref.read(currentSessionIdProvider);
    if (currentId != sessionId) {
      Future.microtask(() {
        ref.read(currentSessionIdProvider.notifier).state = sessionId;
      });
    }

    final eventsAsync = ref.watch(sessionEventsProvider(sessionId));
    final sessionAsync = ref.watch(currentSessionProvider);
    final roundsAsync = ref.watch(roundsProvider);
    final teamsAsync = ref.watch(teamsProvider);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Game Summary'),
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (events) => sessionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (session) => roundsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (rounds) => teamsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (teams) {
                if (session == null) {
                  return Center(
                    child: Text('Game not found',
                        style: TextStyle(color: context.textSecondary)),
                  );
                }
                return _SummaryContent(
                  events: events,
                  session: session,
                  rounds: rounds,
                  teams: teams,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  final List<GameEvent> events;
  final GameSession session;
  final List<Round> rounds;
  final List<Team> teams;

  const _SummaryContent({
    required this.events,
    required this.session,
    required this.rounds,
    required this.teams,
  });

  Color _teamColor(Team team) {
    switch (team.color) {
      case 'red':
        return JetlagColors.red;
      case 'green':
        return JetlagColors.green;
      case 'blue':
        return JetlagColors.accent;
      case 'purple':
        return JetlagColors.purple;
      case 'orange':
        return JetlagColors.orange;
      default:
        return JetlagColors.accent;
    }
  }

  String _teamName(String? teamId) {
    if (teamId == null) return 'Unknown';
    return teams.where((t) => t.id == teamId).firstOrNull?.name ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final completedRounds = rounds
        .where((r) =>
            r.status == RoundStatus.found && r.hideDurationSeconds != null)
        .toList()
      ..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));

    // Derive stats from events
    final questionEvents =
        events.where((e) => e.eventType == 'question_asked').toList();
    final answerEvents =
        events.where((e) => e.eventType == 'question_answered').toList();
    final cardDrawnEvents =
        events.where((e) => e.eventType == 'card_drawn').toList();
    final cardPlayedEvents =
        events.where((e) => e.eventType == 'card_played').toList();
    final phaseEvents =
        events.where((e) => e.eventType == 'phase_change').toList();

    // Key moments
    final keyMoments = _computeKeyMoments(events);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ===== Round Overview (always available from round data) =====
        if (completedRounds.isNotEmpty) ...[
          _SectionLabel(label: 'GAME OVERVIEW'),
          const SizedBox(height: 12),
          ...completedRounds.map((round) {
            final hiderTeam = teams
                .where((t) => t.id == round.hiderTeamId)
                .firstOrNull;
            final seekerTeam = teams
                .where((t) => t.id == round.seekerTeamId)
                .firstOrNull;
            final duration = round.hideDuration ?? Duration.zero;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: JetlagCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: context.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'R${round.roundNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${hiderTeam?.name ?? "?"} hid for ${_formatDuration(duration)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                              ),
                              Text(
                                '${seekerTeam?.name ?? "?"} seeking',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        JetlagTimer(
                          duration: duration,
                          fontSize: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 28),
        ],

        // ===== Timeline (from events) =====
        if (events.isNotEmpty) ...[
          _SectionLabel(label: 'EVENT TIMELINE'),
          const SizedBox(height: 12),
          _TimelineSection(events: events, teams: teams),
          const SizedBox(height: 28),
        ],

        // ===== Question Log =====
        if (questionEvents.isNotEmpty) ...[
          _SectionLabel(label: 'QUESTIONS'),
          const SizedBox(height: 12),
        ],
        if (questionEvents.isEmpty && events.isNotEmpty)
          ...[
            _SectionLabel(label: 'QUESTIONS'),
            const SizedBox(height: 12),
            _EmptyCard(message: 'No questions in event log'),
            const SizedBox(height: 28),
          ]
        else if (questionEvents.isEmpty && events.isEmpty)
          const SizedBox.shrink()
        else
          ...questionEvents.map((q) {
            final answer = answerEvents.where((a) =>
                a.payload['sessionQuestionId'] ==
                q.payload['sessionQuestionId']).firstOrNull;
            final category = q.payload['category'] as String? ?? '';
            final responseTime = answer != null && q.createdAt != null && answer.createdAt != null
                ? answer.createdAt!.difference(q.createdAt!).inSeconds
                : null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: JetlagCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        JetlagBadge(
                          label: _capitalize(category),
                          color: _categoryBadgeColor(category),
                        ),
                        const Spacer(),
                        if (q.createdAt != null)
                          Text(
                            _formatTime(q.createdAt!),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textTertiary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      q.payload['questionId'] as String? ?? 'Question',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                      ),
                    ),
                    if (answer != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: context.green),
                          const SizedBox(width: 6),
                          Text(
                            answer.payload['answerText'] as String? ?? 'Answered',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                          if (responseTime != null) ...[
                            const Spacer(),
                            Text(
                              '${responseTime}s',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textTertiary,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.hourglass_empty, size: 14, color: context.orange),
                          const SizedBox(width: 6),
                          Text(
                            'Unanswered',
                            style: TextStyle(fontSize: 12, color: context.orange),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),

        // ===== Card History (only show if events exist) =====
        if (cardDrawnEvents.isNotEmpty || cardPlayedEvents.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionLabel(label: 'CARDS'),
          const SizedBox(height: 12),
          JetlagCard(
            child: Column(
              children: [
                _StatRow(
                    label: 'Cards Drawn',
                    value: '${cardDrawnEvents.length}',
                    icon: Icons.style),
                if (cardPlayedEvents.isNotEmpty) ...[
                  Divider(color: context.borderSubtle, height: 20),
                  _StatRow(
                      label: 'Cards Played',
                      value: '${cardPlayedEvents.length}',
                      icon: Icons.play_arrow),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),

        // ===== Team Stats =====
        _SectionLabel(label: 'TEAM STATS'),
        const SizedBox(height: 12),
        ...teams.map((team) {
          final teamRounds =
              completedRounds.where((r) => r.hiderTeamId == team.id);
          final totalHide = teamRounds.fold<int>(
              0, (sum, r) => sum + (r.hideDurationSeconds ?? 0));

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: JetlagCard(
              borderColor: team.id == session.winningTeamId
                  ? _teamColor(team).withValues(alpha: 0.4)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _teamColor(team),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        team.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      if (team.id == session.winningTeamId) ...[
                        const SizedBox(width: 8),
                        const JetlagBadge(
                          label: 'Winner',
                          color: JetlagBadgeColor.green,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    label: 'Total Hide Time',
                    value: _formatDuration(Duration(seconds: totalHide)),
                    icon: Icons.timer,
                  ),
                  Divider(color: context.borderSubtle, height: 16),
                  _StatRow(
                    label: 'Rounds Hidden',
                    value: '${teamRounds.length}',
                    icon: Icons.shield,
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 28),

        // ===== Key Moments =====
        if (keyMoments.isNotEmpty) ...[
          _SectionLabel(label: 'KEY MOMENTS'),
          const SizedBox(height: 12),
          ...keyMoments.map((moment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: JetlagCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: context.surface2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child:
                            Icon(moment.icon, size: 18, color: context.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              moment.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              moment.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],

        const SizedBox(height: 28),

        // ===== Phase Timeline =====
        if (phaseEvents.isNotEmpty) ...[
          _SectionLabel(label: 'PHASE CHANGES'),
          const SizedBox(height: 12),
          ...phaseEvents.map((e) {
            final phase = e.payload['phase'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _phaseColor(phase, context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _capitalize(phase),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (e.createdAt != null)
                    Text(
                      _formatTime(e.createdAt!),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            );
          }),
        ],

        // Navigation buttons
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: JetlagButton(
                label: 'Replay',
                icon: Icons.replay,
                variant: JetlagButtonVariant.secondary,
                onPressed: () => context.push('/game/$sessionId/replay'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: JetlagButton(
                label: 'Home',
                icon: Icons.home_outlined,
                variant: JetlagButtonVariant.secondary,
                onPressed: () => context.go('/'),
              ),
            ),
          ],
        ),

        // Use sessionId from parent context
        Builder(builder: (ctx) {
          return const SizedBox(height: 32);
        }),
      ],
    );
  }

  String get sessionId => session.id;

  List<_KeyMoment> _computeKeyMoments(List<GameEvent> events) {
    final moments = <_KeyMoment>[];

    // Fastest answer
    final questionEvents =
        events.where((e) => e.eventType == 'question_asked').toList();
    final answerEvents =
        events.where((e) => e.eventType == 'question_answered').toList();

    int? fastestAnswerTime;
    for (final q in questionEvents) {
      final a = answerEvents.where((a) =>
          a.payload['sessionQuestionId'] ==
          q.payload['sessionQuestionId']).firstOrNull;
      if (a != null && q.createdAt != null && a.createdAt != null) {
        final diff = a.createdAt!.difference(q.createdAt!).inSeconds;
        if (fastestAnswerTime == null || diff < fastestAnswerTime) {
          fastestAnswerTime = diff;
        }
      }
    }
    if (fastestAnswerTime != null) {
      moments.add(_KeyMoment(
        title: 'Fastest Answer',
        description: '${fastestAnswerTime}s response time',
        icon: Icons.bolt,
      ));
    }

    // Longest gap between questions
    if (questionEvents.length >= 2) {
      int longestGap = 0;
      for (var i = 1; i < questionEvents.length; i++) {
        if (questionEvents[i].createdAt != null &&
            questionEvents[i - 1].createdAt != null) {
          final gap = questionEvents[i]
              .createdAt!
              .difference(questionEvents[i - 1].createdAt!)
              .inSeconds;
          if (gap > longestGap) longestGap = gap;
        }
      }
      if (longestGap > 60) {
        moments.add(_KeyMoment(
          title: 'Longest Question Gap',
          description: _formatDuration(Duration(seconds: longestGap)),
          icon: Icons.hourglass_top,
        ));
      }
    }

    // Most cards drawn
    final cardEvents =
        events.where((e) => e.eventType == 'card_drawn').toList();
    if (cardEvents.isNotEmpty) {
      moments.add(_KeyMoment(
        title: 'Total Cards Drawn',
        description: '${cardEvents.length} cards',
        icon: Icons.style,
      ));
    }

    return moments;
  }

  JetlagBadgeColor _categoryBadgeColor(String category) {
    switch (category) {
      case 'matching':
        return JetlagBadgeColor.blue;
      case 'measuring':
        return JetlagBadgeColor.purple;
      case 'radar':
        return JetlagBadgeColor.red;
      case 'thermometer':
        return JetlagBadgeColor.orange;
      case 'tentacles':
        return JetlagBadgeColor.green;
      case 'photo':
        return JetlagBadgeColor.blue;
      default:
        return JetlagBadgeColor.blue;
    }
  }

  Color _phaseColor(String phase, BuildContext context) {
    switch (phase) {
      case 'hiding':
        return context.green;
      case 'seeking':
        return context.red;
      case 'endgame':
        return context.orange;
      default:
        return context.textTertiary;
    }
  }
}

// ============ Helper Widgets ============

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: context.textTertiary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.textTertiary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: context.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return JetlagCard(
      child: Center(
        child: Text(message, style: TextStyle(color: context.textSecondary)),
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  final List<GameEvent> events;
  final List<Team> teams;

  const _TimelineSection({required this.events, required this.teams});

  @override
  Widget build(BuildContext context) {
    // Show key events in timeline format
    final keyEvents = events.where((e) => const [
          'phase_change',
          'question_asked',
          'question_answered',
          'card_played',
          'curse_activated',
          'round_started',
          'round_ended',
          'game_ended',
        ].contains(e.eventType)).toList();

    if (keyEvents.isEmpty) {
      return _EmptyCard(message: 'No events recorded');
    }

    return Column(
      children: keyEvents.take(20).map((event) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline dot + line
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    const SizedBox(height: 5),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _eventColor(event.eventType, context),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _eventLabel(event),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                      if (event.createdAt != null)
                        Text(
                          _formatTime(event.createdAt!),
                          style: TextStyle(
                            fontSize: 10,
                            color: context.textTertiary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _eventColor(String type, BuildContext context) {
    switch (type) {
      case 'phase_change':
        return context.accent;
      case 'question_asked':
        return context.orange;
      case 'question_answered':
        return context.green;
      case 'card_played':
        return context.purple;
      case 'curse_activated':
        return context.red;
      case 'round_started':
      case 'round_ended':
        return context.accent;
      case 'game_ended':
        return context.green;
      default:
        return context.textTertiary;
    }
  }

  String _eventLabel(GameEvent event) {
    switch (event.eventType) {
      case 'phase_change':
        return 'Phase: ${_capitalize(event.payload['phase'] as String? ?? '')}';
      case 'question_asked':
        return 'Question asked (${_capitalize(event.payload['category'] as String? ?? '')})';
      case 'question_answered':
        return 'Question answered';
      case 'card_played':
        return 'Card played';
      case 'curse_activated':
        return 'Curse: ${_capitalize(event.payload['curseType'] as String? ?? '')}';
      case 'round_started':
        return 'Round ${event.payload['roundNumber'] ?? ''} started';
      case 'round_ended':
        return 'Round ended';
      case 'game_ended':
        return 'Game over';
      default:
        return _capitalize(event.eventType.replaceAll('_', ' '));
    }
  }
}

class _KeyMoment {
  final String title;
  final String description;
  final IconData icon;

  _KeyMoment({
    required this.title,
    required this.description,
    required this.icon,
  });
}

// ============ Formatters ============

String _formatTime(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _formatDuration(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }
  return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
