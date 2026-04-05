import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/round_provider.dart';
import '../../design/widgets/widgets.dart';
import '../../design/theme.dart';
import '../../design/colors.dart';
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
    final roundNumber = ref.watch(currentRoundNumberProvider);
    final rounds = ref.watch(roundsProvider).valueOrNull ?? [];
    final totalRounds = rounds.length;

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

        if (session.status == SessionStatus.ended) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/game/${widget.sessionId}/over');
          });
        }

        return Scaffold(
          body: Column(
            children: [
              // Design system status bar
              JetlagStatusBar(
                role: GameRole.spectator,
                label: 'SPECTATING',
                trailing: _buildTrailing(session),
              ),

              // Round indicator
              if (roundNumber > 0)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: context.surface2,
                  child: Row(
                    children: [
                      JetlagBadge(
                        label: _getStatusText(session.status),
                        color: _statusBadgeColor(session.status),
                        showPulse: session.status == SessionStatus.seeking,
                      ),
                      const Spacer(),
                      Text(
                        'Round $roundNumber${totalRounds > 0 ? ' of $totalRounds' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

              // Map + live event feed bottom sheet
              Expanded(
                child: Stack(
                  children: [
                    _buildMap(),
                    JetlagBottomSheet(
                      initialPosition: SheetPosition.collapsed,
                      child: _buildLiveEventFeed(session),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrailing(GameSession session) {
    final formattedTime = ref.watch(formattedRemainingTimeProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formattedTime,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
            color: JetlagColors.darkText2,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            await ref.read(gameActionsProvider).leaveSession();
            if (mounted) context.go('/');
          },
          child: const Icon(Icons.exit_to_app,
              color: JetlagColors.darkText2, size: 18),
        ),
      ],
    );
  }

  Widget _buildMap() {
    try {
      return const GameMap(
        showHiderZone: false,
        showSeekerLocations: true,
      );
    } catch (_) {
      return Container(
        color: JetlagColors.darkSurface2,
        child: const Center(
          child: Text(
            'Map',
            style: TextStyle(fontSize: 18, color: JetlagColors.darkText2),
          ),
        ),
      );
    }
  }

  Widget _buildLiveEventFeed(GameSession session) {
    final participants = ref.watch(participantsProvider).valueOrNull ?? [];
    final questionsAsync = ref.watch(sessionQuestionsProvider);
    final hider = ref.watch(hiderProvider);
    final seekers = ref.watch(seekersProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Players section
          Text(
            'PLAYERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.surface2,
                    borderRadius: BorderRadius.circular(JetlagRadii.sm),
                    border: Border.all(color: context.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const JetlagBadge(
                        label: 'Hider',
                        color: JetlagBadgeColor.green,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hider?.displayName ?? 'None',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.surface2,
                    borderRadius: BorderRadius.circular(JetlagRadii.sm),
                    border: Border.all(color: context.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const JetlagBadge(
                        label: 'Seekers',
                        color: JetlagBadgeColor.red,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        seekers.isEmpty
                            ? 'None'
                            : seekers.map((s) => s.displayName).join(', '),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Event feed section
          Text(
            'LIVE EVENTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          questionsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: $error'),
            ),
            data: (questions) {
              final nonTestQuestions =
                  questions.where((q) => !q.wasTestMode).toList();
              if (nonTestQuestions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No events yet',
                    style: TextStyle(color: context.textTertiary),
                  ),
                );
              }

              return Column(
                children: nonTestQuestions.reversed.take(10).map((sq) {
                  return _buildEventItem(sq);
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEventItem(SessionQuestion sq) {
    final allQuestions = ref.watch(allQuestionsProvider);
    final question = allQuestions.firstWhere(
      (q) => q.id == sq.questionId,
      orElse: () => Question(
        id: sq.questionId,
        text: 'Unknown question',
        category: sq.category,
        cardsDraw: sq.category.cardsDraw,
        cardsKeep: sq.category.cardsKeep,
        responseTimeMinutes: 5,
        answerType: AnswerType.text,
      ),
    );

    final statusColor = switch (sq.status) {
      QuestionStatus.asked => JetlagBadgeColor.orange,
      QuestionStatus.answered => JetlagBadgeColor.green,
      QuestionStatus.expired => JetlagBadgeColor.red,
      QuestionStatus.vetoed => JetlagBadgeColor.purple,
      QuestionStatus.pending => JetlagBadgeColor.blue,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(JetlagRadii.sm),
        border: Border.all(color: context.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sq.answerText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sq.answerText!,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          JetlagBadge(
            label: sq.status.name,
            color: statusColor,
          ),
        ],
      ),
    );
  }

  JetlagBadgeColor _statusBadgeColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.waiting:
        return JetlagBadgeColor.blue;
      case SessionStatus.hiding:
        return JetlagBadgeColor.orange;
      case SessionStatus.seeking:
        return JetlagBadgeColor.red;
      case SessionStatus.paused:
        return JetlagBadgeColor.blue;
      case SessionStatus.ended:
        return JetlagBadgeColor.purple;
    }
  }

  String _getStatusText(SessionStatus status) {
    switch (status) {
      case SessionStatus.waiting:
        return 'Waiting';
      case SessionStatus.hiding:
        return 'Hiding';
      case SessionStatus.seeking:
        return 'Seeking';
      case SessionStatus.paused:
        return 'Paused';
      case SessionStatus.ended:
        return 'Ended';
    }
  }
}
