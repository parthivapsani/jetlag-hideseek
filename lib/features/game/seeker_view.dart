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
import '../questions/question_browser.dart';

class SeekerView extends ConsumerStatefulWidget {
  final String sessionId;

  const SeekerView({super.key, required this.sessionId});

  @override
  ConsumerState<SeekerView> createState() => _SeekerViewState();
}

class _SeekerViewState extends ConsumerState<SeekerView> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    ref.read(currentSessionIdProvider.notifier).state = widget.sessionId;
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    final locationService = ref.read(locationServiceProvider);
    locationService.startTracking(
      onPosition: (position) {
        ref.read(gameActionsProvider)!.updateLocation(
              position.latitude,
              position.longitude,
            );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(currentSessionProvider);
    final activeCursesAsync = ref.watch(activeCursesProvider);
    final roundNumber = ref.watch(currentRoundNumberProvider);

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
                role: GameRole.seeker,
                label: roundNumber > 0
                    ? 'SEEKING  \u2022  ROUND $roundNumber'
                    : 'SEEKING',
                trailing: _buildTimerTrailing(),
              ),

              // Active curses display
              activeCursesAsync.whenData((curses) {
                if (curses.isEmpty) return const SizedBox.shrink();
                return _buildCursesBar(curses);
              }).valueOrNull ??
                  const SizedBox.shrink(),

              // Map + bottom sheet overlay
              Expanded(
                child: Stack(
                  children: [
                    // Full-screen map always visible
                    _buildMap(),

                    // Bottom sheet overlay for Questions tab
                    if (_selectedTab == 1)
                      JetlagBottomSheet(
                        initialPosition: SheetPosition.half,
                        child: const QuestionBrowser(),
                      ),

                    // Bottom sheet overlay for Cards/History tab
                    if (_selectedTab == 2)
                      JetlagBottomSheet(
                        initialPosition: SheetPosition.half,
                        child: _buildQuestionHistory(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: _selectedTab == 0
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      context.push('/game/${widget.sessionId}/draft-question'),
                  backgroundColor: JetlagColors.accent,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Ask Question',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              : null,
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildTimerTrailing() {
    final formattedTime = ref.watch(formattedRemainingTimeProvider);
    final effectiveTime = ref.watch(formattedEffectiveTimeProvider);
    final session = ref.watch(currentSessionProvider).valueOrNull;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$formattedTime / $effectiveTime',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: session != null ? () => _showMenu(session) : null,
          child: const Icon(Icons.more_vert, color: Colors.black, size: 18),
        ),
      ],
    );
  }

  Widget _buildMap() {
    try {
      return const GameMap(
        showHiderZone: false,
        showSeekerLocations: false,
      );
    } catch (_) {
      return Container(
        color: JetlagColors.darkSurface2,
        child: Center(
          child: Text(
            'Map',
            style: TextStyle(
              fontSize: 18,
              color: JetlagColors.darkText2,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      backgroundColor: context.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: JetlagColors.redGlow,
      selectedIndex: _selectedTab,
      onDestinationSelected: (index) {
        if (index == 3) {
          // Team tab navigates to team info page
          _showTeamInfo();
          return;
        }
        setState(() => _selectedTab = index);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map, color: JetlagColors.red),
          label: 'Map',
        ),
        NavigationDestination(
          icon: Icon(Icons.help_outline),
          selectedIcon: Icon(Icons.help, color: JetlagColors.red),
          label: 'Questions',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history, color: JetlagColors.red),
          label: 'Cards',
        ),
        NavigationDestination(
          icon: Icon(Icons.group_outlined),
          selectedIcon: Icon(Icons.group, color: JetlagColors.red),
          label: 'Team',
        ),
      ],
    );
  }

  Widget _buildCursesBar(List<ActiveCurse> curses) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: JetlagColors.orangeGlow,
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: JetlagColors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hider has ${curses.length} active curse(s)',
              style: const TextStyle(
                color: JetlagColors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionHistory() {
    final questionsAsync = ref.watch(sessionQuestionsProvider);

    return questionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text('Error: $error')),
      ),
      data: (questions) {
        if (questions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No questions asked yet',
                style: TextStyle(color: context.textSecondary),
              ),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'QUESTION HISTORY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  JetlagBadge(
                    label: '${questions.length}',
                    color: JetlagBadgeColor.red,
                  ),
                ],
              ),
            ),
            ...questions.map((sq) {
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
              return _QuestionHistoryCard(
                sessionQuestion: sq,
                question: question,
              );
            }),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  void _showTeamInfo() {
    final teams = ref.read(teamsProvider).valueOrNull ?? [];
    final participants = ref.read(participantsProvider).valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'TEAM INFO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ...teams.map((team) {
              final members = participants
                  .where((p) => p.teamId == team.id)
                  .toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (members.isEmpty)
                      Text('No members',
                          style: TextStyle(color: context.textTertiary,
                              fontSize: 13)),
                    ...members.map((m) => Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 14,
                                  color: context.textSecondary),
                              const SizedBox(width: 6),
                              Text(m.displayName,
                                  style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        )),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMenu(GameSession session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.pause),
            title: const Text('Pause Game'),
            onTap: () {
              Navigator.pop(context);
              ref.read(gameActionsProvider)!.pauseGame();
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Leave Game'),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(gameActionsProvider)!.leaveSession();
              if (mounted) this.context.go('/');
            },
          ),
        ],
      ),
    );
  }
}

class _QuestionHistoryCard extends StatelessWidget {
  final SessionQuestion sessionQuestion;
  final Question question;

  const _QuestionHistoryCard({
    required this.sessionQuestion,
    required this.question,
  });

  JetlagBadgeColor _statusBadgeColor(QuestionStatus status) {
    switch (status) {
      case QuestionStatus.asked:
        return JetlagBadgeColor.orange;
      case QuestionStatus.answered:
        return JetlagBadgeColor.green;
      case QuestionStatus.expired:
        return JetlagBadgeColor.red;
      case QuestionStatus.vetoed:
        return JetlagBadgeColor.purple;
      case QuestionStatus.pending:
        return JetlagBadgeColor.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(JetlagRadii.sm),
        border: Border.all(color: context.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              JetlagBadge(
                label: question.category.displayName,
                color: JetlagBadgeColor.blue,
              ),
              const Spacer(),
              JetlagBadge(
                label: sessionQuestion.status.name,
                color: _statusBadgeColor(sessionQuestion.status),
              ),
              if (sessionQuestion.wasTestMode) ...[
                const SizedBox(width: 6),
                JetlagBadge(
                  label: 'TEST',
                  color: JetlagBadgeColor.blue,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question.text,
            style: TextStyle(
              fontSize: 14,
              color: context.textPrimary,
            ),
          ),
          if (sessionQuestion.answerText != null) ...[
            const SizedBox(height: 6),
            Text(
              'Answer: ${sessionQuestion.answerText}',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (sessionQuestion.answerPhotoUrl != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(JetlagRadii.sm),
              child: Image.network(
                sessionQuestion.answerPhotoUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
