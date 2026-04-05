import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/round_provider.dart';
import '../../design/widgets/widgets.dart';
import '../../design/theme.dart';
import '../../design/colors.dart';
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
    final currentQuestion = ref.watch(currentQuestionProvider);
    final blockingCurse = ref.watch(blockingCurseProvider);
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
                role: GameRole.hider,
                label: roundNumber > 0
                    ? 'HIDING  \u2022  ROUND $roundNumber'
                    : 'HIDING',
                trailing: _buildTimerTrailing(),
              ),

              // Blocking curse warning
              if (blockingCurse != null) _buildCurseWarning(blockingCurse),

              // Incoming question banner
              if (currentQuestion != null)
                _buildIncomingQuestionBanner(currentQuestion),

              // Map + bottom sheet overlay
              Expanded(
                child: Stack(
                  children: [
                    // Full-screen map always visible
                    _buildMap(session),

                    // Bottom sheet overlay for Answer tab
                    if (_selectedTab == 1)
                      JetlagBottomSheet(
                        initialPosition: SheetPosition.half,
                        child: currentQuestion != null
                            ? AnswerInterface(sessionQuestion: currentQuestion)
                            : Padding(
                                padding: const EdgeInsets.all(32),
                                child: Center(
                                  child: Text(
                                    'No pending questions',
                                    style: TextStyle(
                                        color: context.textSecondary),
                                  ),
                                ),
                              ),
                      ),

                    // Bottom sheet overlay for Cards tab
                    if (_selectedTab == 2)
                      const JetlagBottomSheet(
                        initialPosition: SheetPosition.half,
                        child: CardDeckView(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomNav(currentQuestion),
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
        GestureDetector(
          onTap: _showTimeBreakdown,
          child: Text(
            '$formattedTime / $effectiveTime',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
              color: Colors.black,
            ),
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

  Widget _buildMap(GameSession session) {
    try {
      return GameMap(
        showHiderZone: true,
        showSeekerLocations: true,
        hiderLocation: _hidingZoneCenter,
        zoneRadius: session.zoneRadiusMeters,
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

  Widget _buildBottomNav(SessionQuestion? currentQuestion) {
    return NavigationBar(
      backgroundColor: context.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: JetlagColors.greenGlow,
      selectedIndex: _selectedTab,
      onDestinationSelected: (index) {
        if (index == 3) {
          _showTeamInfo();
          return;
        }
        setState(() => _selectedTab = index);
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map, color: JetlagColors.green),
          label: 'Map',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: currentQuestion != null,
            backgroundColor: JetlagColors.orange,
            child: const Icon(Icons.question_answer_outlined),
          ),
          selectedIcon:
              const Icon(Icons.question_answer, color: JetlagColors.green),
          label: 'Answer',
        ),
        NavigationDestination(
          icon: Badge(
            label: Text(
              ref.watch(cardsInHandProvider).length.toString(),
              style: const TextStyle(fontSize: 10),
            ),
            isLabelVisible: ref.watch(cardsInHandProvider).isNotEmpty,
            backgroundColor: JetlagColors.green,
            child: const Icon(Icons.style_outlined),
          ),
          selectedIcon: const Icon(Icons.style, color: JetlagColors.green),
          label: 'Cards',
        ),
        const NavigationDestination(
          icon: Icon(Icons.group_outlined),
          selectedIcon: Icon(Icons.group, color: JetlagColors.green),
          label: 'Team',
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: JetlagColors.redGlow,
      child: Row(
        children: [
          const Icon(Icons.lock, color: JetlagColors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: JetlagColors.red,
                    fontSize: 13,
                  ),
                ),
                Text(
                  card.description,
                  style: const TextStyle(
                    color: JetlagColors.red,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (curse.expiresAt != null)
            Text(
              _formatRemainingTime(curse.remainingDuration),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
                color: JetlagColors.red,
                fontWeight: FontWeight.w700,
                fontSize: 13,
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
        cardsDraw: question.category.cardsDraw,
        cardsKeep: question.category.cardsKeep,
        responseTimeMinutes: 5,
        answerType: AnswerType.text,
      ),
    );

    final remainingTime = question.responseDeadline.difference(DateTime.now());
    final isUrgent = remainingTime.inMinutes < 2;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = 1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: isUrgent ? JetlagColors.orangeGlow : JetlagColors.accentGlow,
        child: Row(
          children: [
            Icon(
              Icons.question_answer,
              color: isUrgent ? JetlagColors.orange : JetlagColors.accent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Incoming Question',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isUrgent ? JetlagColors.orange : JetlagColors.accent,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    q.text,
                    style: TextStyle(
                      fontSize: 11,
                      color: isUrgent ? JetlagColors.orange : JetlagColors.accent,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            JetlagBadge(
              label: _formatRemainingTime(remainingTime),
              color: isUrgent ? JetlagBadgeColor.orange : JetlagBadgeColor.blue,
            ),
          ],
        ),
      ),
    );
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
        backgroundColor: this.context.surface,
        title: Text('Time Breakdown',
            style: TextStyle(color: this.context.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _timeRow('Base Time', session.hidingPeriodDuration),
            if (totalBonusPercent > 0)
              _timeRow(
                  '+${(totalBonusPercent * 100).toInt()}% Bonus',
                  Duration(
                      seconds: (session.hidingPeriodSeconds * totalBonusPercent)
                          .round())),
            if (totalBonusMinutes > 0)
              _timeRow('+$totalBonusMinutes min Bonus',
                  Duration(minutes: totalBonusMinutes)),
            Divider(color: this.context.border),
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
      color: context.textPrimary,
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
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
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
        backgroundColor: this.context.surface,
        title: Text('Surrender?',
            style: TextStyle(color: this.context.textPrimary)),
        content: Text(
          'Are you sure you want to surrender? The seekers will win.',
          style: TextStyle(color: this.context.textSecondary),
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
            child: Text('Surrender',
                style: TextStyle(color: this.context.red)),
          ),
        ],
      ),
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
              final members =
                  participants.where((p) => p.teamId == team.id).toList();
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
                          style: TextStyle(
                              color: context.textTertiary, fontSize: 13)),
                    ...members.map((m) => Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.person,
                                  size: 14, color: context.textSecondary),
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
}
