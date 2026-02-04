import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'game_provider.dart';

// ============ Card Definitions ============

final allCardsProvider = Provider<List<GameCard>>((ref) {
  return _allCards;
});

// ============ Hider Cards ============

final hiderCardsProvider = StreamProvider<List<HiderCard>>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) return Stream.value([]);

  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);

  return _cardsStream(service, realtime, sessionId);
});

Stream<List<HiderCard>> _cardsStream(
  SupabaseService service,
  RealtimeService realtime,
  String sessionId,
) async* {
  yield await service.getHiderCards(sessionId);
  yield* realtime.subscribeToCards(sessionId);
}

/// Cards currently in hand
final cardsInHandProvider = Provider<List<HiderCard>>((ref) {
  final cards = ref.watch(hiderCardsProvider).valueOrNull ?? [];
  return cards.where((c) => c.status == CardStatus.inHand).toList();
});

/// Card details for cards in hand
final handWithDetailsProvider = Provider<List<(HiderCard, GameCard)>>((ref) {
  final hand = ref.watch(cardsInHandProvider);
  final allCards = ref.watch(allCardsProvider);

  return hand.map((hiderCard) {
    final gameCard = allCards.firstWhere(
      (c) => c.id == hiderCard.cardId,
      orElse: () => throw Exception('Card not found: ${hiderCard.cardId}'),
    );
    return (hiderCard, gameCard);
  }).toList();
});

// ============ Active Curses ============

final activeCursesProvider = StreamProvider<List<ActiveCurse>>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) return Stream.value([]);

  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);

  return _cursesStream(service, realtime, sessionId);
});

Stream<List<ActiveCurse>> _cursesStream(
  SupabaseService service,
  RealtimeService realtime,
  String sessionId,
) async* {
  yield await service.getActiveCurses(sessionId);
  yield* realtime.subscribeToCurses(sessionId);
}

/// Is hider currently blocked by a curse
final isBlockedByCurseProvider = Provider<bool>((ref) {
  final curses = ref.watch(activeCursesProvider).valueOrNull ?? [];
  return curses.any((c) => c.isBlocking && !c.isExpired);
});

/// Active blocking curse
final blockingCurseProvider = Provider<ActiveCurse?>((ref) {
  final curses = ref.watch(activeCursesProvider).valueOrNull ?? [];
  return curses
      .where((c) => c.isBlocking && !c.isExpired)
      .firstOrNull;
});

// ============ Time Traps ============

final timeTrapsProvider = FutureProvider<List<PlacedTimeTrap>>((ref) async {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) return [];

  final service = ref.watch(supabaseServiceProvider);
  return service.getTimeTraps(sessionId);
});

// ============ Deck State ============

final deckStateProvider = StateNotifierProvider<DeckStateNotifier, DeckState?>((ref) {
  return DeckStateNotifier(ref);
});

class DeckStateNotifier extends StateNotifier<DeckState?> {
  final Ref _ref;

  DeckStateNotifier(this._ref) : super(null);

  void initializeDeck(String sessionId) {
    final allCards = _ref.read(allCardsProvider);
    final shuffled = List<String>.from(allCards.map((c) => c.id))..shuffle(Random());

    state = DeckState(
      sessionId: sessionId,
      drawPile: shuffled,
      discardPile: [],
      totalCardsDrawn: 0,
    );
  }

  String? drawCard() {
    if (state == null) return null;
    if (state!.drawPile.isEmpty) {
      // Reshuffle discard pile
      if (state!.discardPile.isEmpty) return null;
      state = state!.copyWith(
        drawPile: List.from(state!.discardPile)..shuffle(Random()),
        discardPile: [],
      );
    }

    final cardId = state!.drawPile.first;
    state = state!.copyWith(
      drawPile: state!.drawPile.sublist(1),
      totalCardsDrawn: state!.totalCardsDrawn + 1,
    );
    return cardId;
  }

  void discardCard(String cardId) {
    if (state == null) return;
    state = state!.copyWith(
      discardPile: [...state!.discardPile, cardId],
    );
  }
}

// ============ Time Calculation ============

final effectiveHidingTimeProvider = Provider<Duration>((ref) {
  final session = ref.watch(currentSessionProvider).valueOrNull;
  if (session == null) return Duration.zero;

  final baseTime = session.hidingPeriodDuration;
  final cards = ref.watch(handWithDetailsProvider);

  // Calculate time bonuses
  int bonusMinutes = 0;
  double bonusPercentage = 0;

  for (final (_, gameCard) in cards) {
    if (gameCard.type == CardType.timeBonus) {
      if (gameCard.timeBonusMinutes != null) {
        bonusMinutes += gameCard.timeBonusMinutes!;
      }
      if (gameCard.timeBonusPercentage != null) {
        bonusPercentage += gameCard.timeBonusPercentage!;
      }
    }
  }

  // Apply percentage first, then flat bonus
  final percentageBonus = baseTime.inSeconds * bonusPercentage;
  final totalSeconds = baseTime.inSeconds + percentageBonus.round() + (bonusMinutes * 60);

  return Duration(seconds: totalSeconds.toInt());
});

// ============ Card Actions ============

final cardActionsProvider = Provider<CardActions>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return CardActions(ref, service);
});

class CardActions {
  final Ref _ref;
  final SupabaseService _service;

  CardActions(this._ref, this._service);

  Future<HiderCard?> drawCard() async {
    final sessionId = _ref.read(currentSessionIdProvider);
    if (sessionId == null) return null;

    final deckState = _ref.read(deckStateProvider.notifier);
    final cardId = deckState.drawCard();
    if (cardId == null) return null;

    return await _service.drawCard(sessionId: sessionId, cardId: cardId);
  }

  Future<void> playCard(String hiderCardId, String cardId) async {
    await _service.playCard(hiderCardId);
    _ref.read(deckStateProvider.notifier).discardCard(cardId);
  }

  Future<void> discardCard(String hiderCardId, String cardId) async {
    await _service.discardCard(hiderCardId);
    _ref.read(deckStateProvider.notifier).discardCard(cardId);
  }

  Future<ActiveCurse> activateCurse({
    required String cardId,
    required CurseType curseType,
    int? durationMinutes,
    String? condition,
    bool isBlocking = false,
  }) async {
    final sessionId = _ref.read(currentSessionIdProvider);
    if (sessionId == null) throw Exception('No active session');

    return await _service.activateCurse(
      sessionId: sessionId,
      cardId: cardId,
      curseType: curseType,
      durationMinutes: durationMinutes,
      condition: condition,
      isBlocking: isBlocking,
    );
  }

  Future<void> removeCurse(String curseId) async {
    await _service.deactivateCurse(curseId);
  }

  Future<PlacedTimeTrap> placeTimeTrap({
    required String cardId,
    required String stationId,
    required String stationName,
    required double latitude,
    required double longitude,
  }) async {
    final sessionId = _ref.read(currentSessionIdProvider);
    if (sessionId == null) throw Exception('No active session');

    return await _service.placeTimeTrap(
      sessionId: sessionId,
      cardId: cardId,
      stationId: stationId,
      stationName: stationName,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> triggerTimeTrap(String trapId) async {
    final participantId = _ref.read(currentParticipantIdProvider);
    if (participantId == null) return;
    await _service.triggerTimeTrap(trapId, participantId);
  }
}

// ============ Card Database ============

const _allCards = <GameCard>[
  // Time Bonuses
  GameCard(
    id: 'time_5',
    name: '+5 Minutes',
    description: 'Add 5 minutes to your hiding time.',
    type: CardType.timeBonus,
    timeBonusMinutes: 5,
    rules: 'Hold until the end of the round. Adds 5 minutes to your effective hiding time.',
  ),
  GameCard(
    id: 'time_10',
    name: '+10 Minutes',
    description: 'Add 10 minutes to your hiding time.',
    type: CardType.timeBonus,
    timeBonusMinutes: 10,
    rules: 'Hold until the end of the round. Adds 10 minutes to your effective hiding time.',
  ),
  GameCard(
    id: 'time_15',
    name: '+15 Minutes',
    description: 'Add 15 minutes to your hiding time.',
    type: CardType.timeBonus,
    timeBonusMinutes: 15,
    rules: 'Hold until the end of the round. Adds 15 minutes to your effective hiding time.',
  ),
  GameCard(
    id: 'time_10pct',
    name: '+10% Time',
    description: 'Add 10% to your hiding time.',
    type: CardType.timeBonus,
    timeBonusPercentage: 0.10,
    rules: 'Hold until the end of the round. Adds 10% to your base hiding time.',
  ),

  // Powerups
  GameCard(
    id: 'veto',
    name: 'Veto',
    description: 'Cancel the current question without answering.',
    type: CardType.powerup,
    powerupEffect: 'veto_question',
    playCondition: 'Can only be played when a question is pending.',
    rules: 'Play immediately after a question is asked to cancel it. The seekers do not draw cards.',
    canBeVetoed: false,
  ),
  GameCard(
    id: 'randomize',
    name: 'Randomize',
    description: 'Force the seekers to ask a random question from a category.',
    type: CardType.powerup,
    powerupEffect: 'randomize_question',
    rules: 'Play before a question is asked. The seekers must use the randomly selected question.',
  ),
  GameCard(
    id: 'discard_draw',
    name: 'Discard & Draw',
    description: 'Discard up to 3 cards and draw that many new cards.',
    type: CardType.powerup,
    powerupEffect: 'discard_draw',
    rules: 'Choose up to 3 cards from your hand to discard, then draw the same number.',
  ),
  GameCard(
    id: 'move',
    name: 'Move',
    description: 'You may move to a new location and establish a new hiding zone.',
    type: CardType.powerup,
    powerupEffect: 'move',
    rules: 'You have 30 minutes to travel to a new location and establish a new hiding zone.',
  ),
  GameCard(
    id: 'duplicate',
    name: 'Duplicate',
    description: 'Copy the effect of another card in your hand.',
    type: CardType.powerup,
    powerupEffect: 'duplicate',
    rules: 'Choose another card in your hand. This card has the same effect.',
  ),

  // Curses
  GameCard(
    id: 'express_route',
    name: 'Express Route',
    description: 'The hider must stay on their current transit vehicle for 30 minutes.',
    type: CardType.curse,
    curseType: CurseType.expressRoute,
    curseDurationMinutes: 30,
    isBlocking: true,
    rules: 'The hider cannot exit their current transit vehicle for 30 minutes. If not on transit, they must board the next available transit.',
  ),
  GameCard(
    id: 'long_shot',
    name: 'Long Shot',
    description: 'The hider is frozen until the next question is answered.',
    type: CardType.curse,
    curseType: CurseType.longShot,
    isBlocking: true,
    curseCondition: 'question_answered',
    rules: 'The hider cannot move until the seekers ask another question and it is answered.',
  ),
  GameCard(
    id: 'runner',
    name: 'Runner',
    description: 'The hider must move at least 0.25 miles within 15 minutes.',
    type: CardType.curse,
    curseType: CurseType.runner,
    curseDurationMinutes: 15,
    rules: 'The hider must travel at least 0.25 miles from their current position within 15 minutes.',
  ),
  GameCard(
    id: 'museum',
    name: 'Museum',
    description: 'The hider must stay in place for 20 minutes.',
    type: CardType.curse,
    curseType: CurseType.museum,
    curseDurationMinutes: 20,
    isBlocking: true,
    rules: 'The hider cannot move more than 100 feet from their current position for 20 minutes.',
  ),

  // Time Traps
  GameCard(
    id: 'time_trap_1',
    name: 'Time Trap',
    description: 'Place at a station. Gain bonus time for each hour it remains untriggered.',
    type: CardType.timeTrap,
    trapBonusPerHourMinutes: 5,
    rules: 'Place this card at a transit station. For each hour it remains untriggered, gain 5 minutes of hiding time. Triggered when a seeker visits the station.',
  ),
  GameCard(
    id: 'time_trap_2',
    name: 'Time Trap',
    description: 'Place at a station. Gain bonus time for each hour it remains untriggered.',
    type: CardType.timeTrap,
    trapBonusPerHourMinutes: 5,
    rules: 'Place this card at a transit station. For each hour it remains untriggered, gain 5 minutes of hiding time. Triggered when a seeker visits the station.',
  ),
];
