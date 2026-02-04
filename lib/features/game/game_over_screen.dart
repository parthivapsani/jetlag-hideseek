import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../app/theme.dart';

class GameOverScreen extends ConsumerWidget {
  final String sessionId;

  const GameOverScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(currentSessionProvider);
    final participantsAsync = ref.watch(participantsProvider);
    final questionsAsync = ref.watch(sessionQuestionsProvider);
    final currentParticipant = ref.watch(currentParticipantProvider);

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

        return participantsAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Scaffold(
            body: Center(child: Text('Error: $error')),
          ),
          data: (participants) {
            final hider = participants
                .where((p) => p.role == ParticipantRole.hider)
                .firstOrNull;
            final seekers = participants
                .where((p) => p.role == ParticipantRole.seeker)
                .toList();

            // Determine winner
            final bool seekersWon = session.winnerId != null &&
                seekers.any((s) => s.id == session.winnerId);
            final bool hiderWon = session.winnerId == null ||
                session.winnerId == hider?.id;

            final isCurrentUserWinner = (hiderWon && currentParticipant?.role == ParticipantRole.hider) ||
                (seekersWon && currentParticipant?.role == ParticipantRole.seeker);

            return Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    // Result banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: hiderWon
                              ? [JetLagTheme.hiderGreen, JetLagTheme.hiderGreen.withOpacity(0.7)]
                              : [JetLagTheme.seekerRed, JetLagTheme.seekerRed.withOpacity(0.7)],
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isCurrentUserWinner ? Icons.emoji_events : Icons.close,
                            size: 64,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isCurrentUserWinner ? 'You Won!' : 'Game Over',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hiderWon
                                ? 'The hider survived!'
                                : 'The seekers found the hider!',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stats
                    Expanded(
                      child: questionsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, _) => Center(child: Text('Error: $error')),
                        data: (questions) {
                          final officialQuestions = questions
                              .where((q) => !q.wasTestMode)
                              .toList();
                          final answeredQuestions = officialQuestions
                              .where((q) => q.status == QuestionStatus.answered)
                              .toList();
                          final vetoedQuestions = officialQuestions
                              .where((q) => q.status == QuestionStatus.vetoed)
                              .toList();

                          return ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              _StatCard(
                                title: 'Game Duration',
                                value: _formatDuration(
                                  session.endedAt?.difference(
                                    session.hidingStartedAt ?? session.createdAt,
                                  ) ?? Duration.zero,
                                ),
                                icon: Icons.timer,
                              ),
                              const SizedBox(height: 12),
                              _StatCard(
                                title: 'Questions Asked',
                                value: '${officialQuestions.length}',
                                icon: Icons.question_answer,
                              ),
                              const SizedBox(height: 12),
                              _StatCard(
                                title: 'Questions Answered',
                                value: '${answeredQuestions.length}',
                                icon: Icons.check_circle,
                              ),
                              if (vetoedQuestions.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _StatCard(
                                  title: 'Questions Vetoed',
                                  value: '${vetoedQuestions.length}',
                                  icon: Icons.block,
                                ),
                              ],
                              const SizedBox(height: 24),
                              const Text(
                                'Players',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (hider != null)
                                _PlayerCard(
                                  participant: hider,
                                  isWinner: hiderWon,
                                ),
                              ...seekers.map((seeker) => _PlayerCard(
                                    participant: seeker,
                                    isWinner: seekersWon,
                                  )),
                            ],
                          );
                        },
                      ),
                    ),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await ref.read(gameActionsProvider).leaveSession();
                                if (context.mounted) context.go('/');
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Home'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // TODO: Implement rematch
                                context.go('/');
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Play Again'),
                            ),
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
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final Participant participant;
  final bool isWinner;

  const _PlayerCard({
    required this.participant,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = participant.role == ParticipantRole.hider
        ? JetLagTheme.hiderGreen
        : JetLagTheme.seekerRed;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor,
          child: Text(
            participant.displayName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Row(
          children: [
            Text(participant.displayName),
            if (isWinner)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
          ],
        ),
        subtitle: Text(
          participant.role.name[0].toUpperCase() +
              participant.role.name.substring(1),
          style: TextStyle(color: roleColor),
        ),
      ),
    );
  }
}
