import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/widgets.dart';

class GameOverScreen extends ConsumerWidget {
  final String sessionId;

  const GameOverScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ensure session ID is set so dependent providers can load data
    final currentId = ref.read(currentSessionIdProvider);
    if (currentId != sessionId) {
      Future.microtask(() {
        ref.read(currentSessionIdProvider.notifier).state = sessionId;
      });
    }

    final sessionAsync = ref.watch(currentSessionProvider);
    final roundsAsync = ref.watch(roundsProvider);
    final teamsAsync = ref.watch(teamsProvider);

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: sessionAsync.when(
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Game not found',
                          style: TextStyle(color: context.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        JetlagButton(
                          label: 'Go Home',
                          onPressed: () => context.go('/'),
                        ),
                      ],
                    ),
                  );
                }
                return _buildContent(context, ref, session, rounds, teams);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    GameSession session,
    List<Round> rounds,
    List<Team> teams,
  ) {
    // Find winning team
    final winningTeam = teams
        .where((t) => t.id == session.winningTeamId)
        .firstOrNull;

    // Compute total hide times per team
    final completedRounds = rounds
        .where((r) =>
            r.status == RoundStatus.found && r.hideDurationSeconds != null)
        .toList()
      ..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));

    final hideTimes = <String, int>{};
    for (final round in completedRounds) {
      if (round.hiderTeamId != null) {
        hideTimes[round.hiderTeamId!] =
            (hideTimes[round.hiderTeamId!] ?? 0) + round.hideDurationSeconds!;
      }
    }

    // Team color helper
    Color teamColor(Team team) {
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

    return Column(
      children: [
        // Winner banner
        _WinnerBanner(
          winningTeam: winningTeam,
          teamColor: winningTeam != null ? teamColor(winningTeam) : context.accent,
          isOverride: session.winnerOverride,
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total hide time comparison
                Text(
                  'TOTAL HIDE TIME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ...teams.map((team) {
                  final totalSeconds = hideTimes[team.id] ?? 0;
                  final isWinner = team.id == session.winningTeamId;
                  final maxSeconds = hideTimes.values.isEmpty
                      ? 1
                      : hideTimes.values.reduce((a, b) => a > b ? a : b);
                  final fraction =
                      maxSeconds > 0 ? totalSeconds / maxSeconds : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: JetlagCard(
                      borderColor: isWinner
                          ? teamColor(team).withValues(alpha: 0.5)
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: teamColor(team),
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
                              const Spacer(),
                              if (isWinner)
                                const JetlagBadge(
                                  label: 'Winner',
                                  color: JetlagBadgeColor.green,
                                ),
                              const SizedBox(width: 8),
                              JetlagTimer(
                                duration: Duration(seconds: totalSeconds),
                                fontSize: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 6,
                              backgroundColor:
                                  context.surface2,
                              valueColor: AlwaysStoppedAnimation(
                                teamColor(team),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Round-by-round breakdown
                Text(
                  'ROUND BY ROUND',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ...completedRounds.map((round) {
                  final hiderTeam = teams
                      .where((t) => t.id == round.hiderTeamId)
                      .firstOrNull;
                  final duration =
                      round.hideDuration ?? Duration.zero;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: JetlagCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: context.surface2,
                              borderRadius:
                                  BorderRadius.circular(JetlagRadii.sm),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${round.roundNumber}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hiderTeam?.name ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                ),
                                Text(
                                  'was hiding',
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
                    ),
                  );
                }),

                // Admin override badge
                if (session.winnerOverride) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: JetlagBadge(
                      label: 'Admin Override',
                      color: JetlagBadgeColor.orange,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Home button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            width: double.infinity,
            child: JetlagButton(
              label: 'Home',
              icon: Icons.home_outlined,
              variant: JetlagButtonVariant.secondary,
              onPressed: () async {
                await ref.read(gameActionsProvider)?.leaveSession();
                if (context.mounted) context.go('/');
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  final Team? winningTeam;
  final Color teamColor;
  final bool isOverride;

  const _WinnerBanner({
    required this.winningTeam,
    required this.teamColor,
    required this.isOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            teamColor.withValues(alpha: 0.3),
            teamColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events,
            size: 48,
            color: teamColor,
          ),
          const SizedBox(height: 12),
          Text(
            winningTeam?.name ?? 'No Winner',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'WINNER',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: teamColor,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
