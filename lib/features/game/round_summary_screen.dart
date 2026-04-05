import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/widgets.dart';

class RoundSummaryScreen extends ConsumerWidget {
  final String sessionId;

  const RoundSummaryScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundsAsync = ref.watch(roundsProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final sessionAsync = ref.watch(currentSessionProvider);

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: roundsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (rounds) => teamsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (teams) => sessionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (session) {
                if (session == null || rounds.isEmpty) {
                  return Center(
                    child: Text(
                      'No round data available',
                      style: TextStyle(color: context.textSecondary),
                    ),
                  );
                }
                return _buildContent(context, ref, rounds, teams, session);
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
    List<Round> rounds,
    List<Team> teams,
    GameSession session,
  ) {
    // Find the most recently completed round
    final completedRounds = rounds
        .where((r) => r.status == RoundStatus.found)
        .toList()
      ..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));

    if (completedRounds.isEmpty) {
      return Center(
        child: Text(
          'No completed rounds yet',
          style: TextStyle(color: context.textSecondary),
        ),
      );
    }

    final lastCompleted = completedRounds.last;
    final roundNumber = lastCompleted.roundNumber;
    final isLastRound = roundNumber >= session.totalRounds;

    // Team lookups
    final hiderTeam = teams.where((t) => t.id == lastCompleted.hiderTeamId).firstOrNull;
    final seekerTeam = teams.where((t) => t.id == lastCompleted.seekerTeamId).firstOrNull;

    // For the next round, roles swap
    final nextHiderTeam = seekerTeam;
    final nextSeekerTeam = hiderTeam;

    // Hide duration
    final hideDuration = lastCompleted.hideDuration ?? Duration.zero;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          // Header with gradient text
          _GradientText(
            text: 'Round $roundNumber Complete',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${hiderTeam?.name ?? "Hider"} was found!',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Hide time card
          JetlagCard(
            child: Column(
              children: [
                Text(
                  'Hide Time Achieved',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                JetlagTimer(
                  duration: hideDuration,
                  fontSize: 36,
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${hiderTeam?.name ?? "Unknown Team"}',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats card (placeholder values for now)
          JetlagCard(
            child: Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Questions Asked',
                    value: '--',
                    icon: Icons.question_answer_outlined,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: context.borderSubtle,
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Cards Played',
                    value: '--',
                    icon: Icons.style_outlined,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Role swap visualization (only if not last round)
          if (!isLastRound && nextHiderTeam != null && nextSeekerTeam != null) ...[
            JetlagCard(
              child: Column(
                children: [
                  Text(
                    'Role Swap',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleChip(
                          teamName: hiderTeam?.name ?? '?',
                          role: 'HIDING',
                          color: JetlagColors.green,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.arrow_forward,
                          color: context.textTertiary,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: _RoleChip(
                          teamName: hiderTeam?.name ?? '?',
                          role: 'SEEKING',
                          color: JetlagColors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleChip(
                          teamName: seekerTeam?.name ?? '?',
                          role: 'SEEKING',
                          color: JetlagColors.red,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.arrow_forward,
                          color: context.textTertiary,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: _RoleChip(
                          teamName: seekerTeam?.name ?? '?',
                          role: 'HIDING',
                          color: JetlagColors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          // Bottom action
          if (!isLastRound) ...[
            Text(
              '${nextHiderTeam?.name ?? "Next team"} needs to hide for longer than ${_formatDuration(hideDuration)} to win',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: JetlagButton(
                label: 'Start Round ${roundNumber + 1}',
                icon: Icons.play_arrow,
                onPressed: () {
                  // Navigate back to lobby/game setup for the next round
                  context.go('/lobby/$sessionId');
                },
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: JetlagButton(
                label: 'View Results',
                icon: Icons.emoji_events_outlined,
                onPressed: () {
                  context.go('/game/$sessionId/over');
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _GradientText({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          context.accent,
          context.purple,
        ],
      ).createShader(bounds),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: context.textTertiary),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: context.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String teamName;
  final String role;
  final Color color;

  const _RoleChip({
    required this.teamName,
    required this.role,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(JetlagRadii.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            teamName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            role,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
