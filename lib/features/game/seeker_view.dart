import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../app/theme.dart';
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
        ref.read(gameActionsProvider).updateLocation(
              position.latitude,
              position.longitude,
            );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(currentSessionProvider);
    final timerState = ref.watch(timerProvider);
    final activeCursesAsync = ref.watch(activeCursesProvider);

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
                // Header with timer
                _buildHeader(session, timerState),

                // Active curses display
                activeCursesAsync.whenData((curses) {
                  if (curses.isEmpty) return const SizedBox.shrink();
                  return _buildCursesBar(curses);
                }).valueOrNull ?? const SizedBox.shrink(),

                // Main content
                Expanded(
                  child: IndexedStack(
                    index: _selectedTab,
                    children: [
                      // Map tab
                      const GameMap(
                        showHiderZone: false,
                        showSeekerLocations: false,
                      ),
                      // Questions tab
                      const QuestionBrowser(),
                      // History tab
                      _buildQuestionHistory(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) => setState(() => _selectedTab = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Map',
              ),
              NavigationDestination(
                icon: Icon(Icons.question_mark_outlined),
                selectedIcon: Icon(Icons.question_mark),
                label: 'Questions',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'History',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(GameSession session, TimerState timerState) {
    final formattedTime = ref.watch(formattedRemainingTimeProvider);
    final effectiveTime = ref.watch(formattedEffectiveTimeProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      color: JetLagTheme.seekerRed,
      child: Row(
        children: [
          // Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(session.status),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'SEEKER',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Timer
          Column(
            children: [
              Text(
                formattedTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'of $effectiveTime',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          // Menu
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _showMenu(session),
          ),
        ],
      ),
    );
  }

  Widget _buildCursesBar(List<ActiveCurse> curses) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade100,
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hider has ${curses.length} active curse(s)',
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionHistory() {
    final questionsAsync = ref.watch(sessionQuestionsProvider);

    return questionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (questions) {
        if (questions.isEmpty) {
          return const Center(
            child: Text('No questions asked yet'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: questions.length,
          itemBuilder: (context, index) {
            final sq = questions[index];
            final allQuestions = ref.watch(allQuestionsProvider);
            final question = allQuestions.firstWhere(
              (q) => q.id == sq.questionId,
              orElse: () => Question(
                id: sq.questionId,
                text: 'Unknown question',
                category: sq.category,
                coinCost: 0,
                cardsDrawn: 0,
                responseTimeMinutes: 5,
                answerType: AnswerType.text,
              ),
            );

            return _QuestionHistoryCard(
              sessionQuestion: sq,
              question: question,
            );
          },
        );
      },
    );
  }

  String _getStatusText(SessionStatus status) {
    switch (status) {
      case SessionStatus.waiting:
        return 'Waiting';
      case SessionStatus.hiding:
        return 'Hiding Period';
      case SessionStatus.seeking:
        return 'Seeking';
      case SessionStatus.paused:
        return 'Paused';
      case SessionStatus.ended:
        return 'Game Over';
    }
  }

  void _showMenu(GameSession session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.pause),
            title: const Text('Pause Game'),
            onTap: () {
              Navigator.pop(context);
              ref.read(gameActionsProvider).pauseGame();
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Leave Game'),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(gameActionsProvider).leaveSession();
              if (mounted) context.go('/');
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

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (sessionQuestion.status) {
      QuestionStatus.asked => Colors.orange,
      QuestionStatus.answered => Colors.green,
      QuestionStatus.expired => Colors.red,
      QuestionStatus.vetoed => Colors.purple,
      QuestionStatus.pending => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: question.category.displayName == 'Relative'
                        ? Colors.blue
                        : question.category.displayName == 'Radar'
                            ? Colors.purple
                            : question.category.displayName == 'Photo'
                                ? Colors.green
                                : question.category.displayName == 'Oddball'
                                    ? Colors.orange
                                    : Colors.teal,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    question.category.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sessionQuestion.status.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (sessionQuestion.wasTestMode)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TEST',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.text,
              style: const TextStyle(fontSize: 16),
            ),
            if (sessionQuestion.answerText != null) ...[
              const SizedBox(height: 8),
              Text(
                'Answer: ${sessionQuestion.answerText}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (sessionQuestion.answerPhotoUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
      ),
    );
  }
}
