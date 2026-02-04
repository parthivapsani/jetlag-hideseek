import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../app/theme.dart';
import 'game_map.dart';
import '../cards/card_deck_view.dart';
import '../questions/answer_interface.dart';

class HiderView extends ConsumerStatefulWidget {
  final String sessionId;

  const HiderView({super.key, required this.sessionId});

  @override
  ConsumerState<HiderView> createState() => _HiderViewState();
}

class _HiderViewState extends ConsumerState<HiderView> {
  int _selectedTab = 0;
  LatLng? _hidingZoneCenter;

  @override
  void initState() {
    super.initState();
    ref.read(currentSessionIdProvider.notifier).state = widget.sessionId;
    _initializeHidingZone();
    _startLocationUpdates();
    _initializeDeck();
  }

  void _initializeHidingZone() async {
    final locationService = ref.read(locationServiceProvider);
    final position = await locationService.getCurrentPosition();
    if (position != null) {
      setState(() {
        _hidingZoneCenter = LatLng(position.latitude, position.longitude);
      });
    }
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

  void _initializeDeck() {
    final deckNotifier = ref.read(deckStateProvider.notifier);
    deckNotifier.initializeDeck(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(currentSessionProvider);
    final timerState = ref.watch(timerProvider);
    final currentQuestion = ref.watch(currentQuestionProvider);
    final blockingCurse = ref.watch(blockingCurseProvider);

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

                // Blocking curse warning
                if (blockingCurse != null) _buildCurseWarning(blockingCurse),

                // Incoming question banner
                if (currentQuestion != null)
                  _buildIncomingQuestionBanner(currentQuestion),

                // Main content
                Expanded(
                  child: IndexedStack(
                    index: _selectedTab,
                    children: [
                      // Map tab
                      GameMap(
                        showHiderZone: true,
                        showSeekerLocations: true,
                        hiderLocation: _hidingZoneCenter,
                        zoneRadius: session.zoneRadiusMeters,
                      ),
                      // Cards tab
                      const CardDeckView(),
                      // Answer tab (shows when question pending)
                      currentQuestion != null
                          ? AnswerInterface(sessionQuestion: currentQuestion)
                          : const Center(child: Text('No pending questions')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) => setState(() => _selectedTab = index),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Map',
              ),
              NavigationDestination(
                icon: Badge(
                  label: Text(
                    ref.watch(cardsInHandProvider).length.toString(),
                  ),
                  isLabelVisible: ref.watch(cardsInHandProvider).isNotEmpty,
                  child: const Icon(Icons.style_outlined),
                ),
                selectedIcon: const Icon(Icons.style),
                label: 'Cards',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: currentQuestion != null,
                  child: const Icon(Icons.question_answer_outlined),
                ),
                selectedIcon: const Icon(Icons.question_answer),
                label: 'Answer',
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
      color: JetLagTheme.hiderGreen,
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
                const Text(
                  'HIDER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Timer
          GestureDetector(
            onTap: () => _showTimeBreakdown(),
            child: Column(
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
                Row(
                  children: [
                    Text(
                      'of $effectiveTime',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ],
                ),
              ],
            ),
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

  Widget _buildCurseWarning(ActiveCurse curse) {
    final allCards = ref.watch(allCardsProvider);
    final card = allCards.firstWhere(
      (c) => c.id == curse.cardId,
      orElse: () => GameCard(
        id: curse.cardId,
        name: 'Unknown Curse',
        description: 'You are cursed',
        type: CardType.curse,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.red.shade100,
      child: Row(
        children: [
          const Icon(Icons.lock, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                Text(
                  card.description,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (curse.expiresAt != null)
            Text(
              _formatRemainingTime(curse.remainingDuration),
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIncomingQuestionBanner(SessionQuestion question) {
    final allQuestions = ref.watch(allQuestionsProvider);
    final q = allQuestions.firstWhere(
      (qn) => qn.id == question.questionId,
      orElse: () => Question(
        id: question.questionId,
        text: 'Unknown question',
        category: question.category,
        coinCost: 0,
        cardsDrawn: 0,
        responseTimeMinutes: 5,
        answerType: AnswerType.text,
      ),
    );

    final remainingTime = question.responseDeadline.difference(DateTime.now());
    final isUrgent = remainingTime.inMinutes < 2;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = 2),
      child: Container(
        padding: const EdgeInsets.all(12),
        color: isUrgent ? Colors.orange.shade100 : Colors.blue.shade100,
        child: Row(
          children: [
            Icon(
              Icons.question_answer,
              color: isUrgent ? Colors.orange : Colors.blue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Incoming Question',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isUrgent ? Colors.orange.shade800 : Colors.blue.shade800,
                    ),
                  ),
                  Text(
                    q.text,
                    style: TextStyle(
                      fontSize: 12,
                      color: isUrgent ? Colors.orange.shade700 : Colors.blue.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isUrgent ? Colors.orange : Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatRemainingTime(remainingTime),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(SessionStatus status) {
    switch (status) {
      case SessionStatus.waiting:
        return 'Waiting';
      case SessionStatus.hiding:
        return 'Hiding Period';
      case SessionStatus.seeking:
        return 'Being Sought';
      case SessionStatus.paused:
        return 'Paused';
      case SessionStatus.ended:
        return 'Game Over';
    }
  }

  String _formatRemainingTime(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showTimeBreakdown() {
    final session = ref.read(currentSessionProvider).valueOrNull;
    final handWithDetails = ref.read(handWithDetailsProvider);
    final effectiveTime = ref.read(effectiveHidingTimeProvider);

    if (session == null) return;

    int totalBonusMinutes = 0;
    double totalBonusPercent = 0;

    for (final (_, card) in handWithDetails) {
      if (card.type == CardType.timeBonus) {
        if (card.timeBonusMinutes != null) {
          totalBonusMinutes += card.timeBonusMinutes!;
        }
        if (card.timeBonusPercentage != null) {
          totalBonusPercent += card.timeBonusPercentage!;
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Time Breakdown'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _timeRow('Base Time', session.hidingPeriodDuration),
            if (totalBonusPercent > 0)
              _timeRow('+${(totalBonusPercent * 100).toInt()}% Bonus',
                  Duration(seconds: (session.hidingPeriodSeconds * totalBonusPercent).round())),
            if (totalBonusMinutes > 0)
              _timeRow('+$totalBonusMinutes min Bonus',
                  Duration(minutes: totalBonusMinutes)),
            const Divider(),
            _timeRow('Effective Time', effectiveTime, isBold: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _timeRow(String label, Duration duration, {bool isBold = false}) {
    final style = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(_formatDuration(duration), style: style),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  void _showMenu(GameSession session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session.status == SessionStatus.hiding)
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Start Seeking Phase'),
              subtitle: const Text('End hiding period early'),
              onTap: () {
                Navigator.pop(context);
                ref.read(gameActionsProvider).startSeeking();
              },
            ),
          ListTile(
            leading: const Icon(Icons.pause),
            title: const Text('Pause Game'),
            onTap: () {
              Navigator.pop(context);
              ref.read(gameActionsProvider).pauseGame();
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('Surrender'),
            subtitle: const Text('End game - seekers win'),
            onTap: () {
              Navigator.pop(context);
              _confirmSurrender();
            },
          ),
        ],
      ),
    );
  }

  void _confirmSurrender() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Surrender?'),
        content: const Text(
          'Are you sure you want to surrender? The seekers will win.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final seekers = ref.read(seekersProvider);
              ref.read(gameActionsProvider).endGame(
                    winnerId: seekers.isNotEmpty ? seekers.first.id : null,
                  );
            },
            child: const Text('Surrender'),
          ),
        ],
      ),
    );
  }
}
