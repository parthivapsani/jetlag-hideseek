import 'package:freezed_annotation/freezed_annotation.dart';

part 'card.freezed.dart';
part 'card.g.dart';

enum CardType {
  @JsonValue('time_bonus')
  timeBonus,
  @JsonValue('powerup')
  powerup,
  @JsonValue('curse')
  curse,
  @JsonValue('time_trap')
  timeTrap,
}

enum CardStatus {
  @JsonValue('in_deck')
  inDeck,
  @JsonValue('in_hand')
  inHand,
  @JsonValue('played')
  played,
  @JsonValue('discarded')
  discarded,
}

enum CurseType {
  @JsonValue('express_route')
  expressRoute, // 30 min stuck on train
  @JsonValue('long_shot')
  longShot, // Frozen until question answered
  @JsonValue('runner')
  runner, // Must move X distance
  @JsonValue('museum')
  museum, // Must stay in place
}

@freezed
class GameCard with _$GameCard {
  const factory GameCard({
    required String id,
    required String name,
    required String description,
    required CardType type,
    // Time bonus fields
    int? timeBonusMinutes,
    double? timeBonusPercentage,
    // Powerup fields
    String? powerupEffect,
    // Curse fields
    CurseType? curseType,
    int? curseDurationMinutes,
    String? curseCondition,
    // Time trap fields
    int? trapBonusPerHourMinutes,
    // General
    String? playCondition,
    @Default(false) bool isBlocking, // Prevents other cards from being played
    String? rules,
  }) = _GameCard;

  factory GameCard.fromJson(Map<String, dynamic> json) =>
      _$GameCardFromJson(json);
}

@freezed
class HiderCard with _$HiderCard {
  const factory HiderCard({
    required String id,
    required String sessionId,
    required String cardId,
    required CardStatus status,
    required DateTime drawnAt,
    DateTime? playedAt,
    DateTime? discardedAt,
  }) = _HiderCard;

  factory HiderCard.fromJson(Map<String, dynamic> json) =>
      _$HiderCardFromJson(json);
}

@freezed
class ActiveCurse with _$ActiveCurse {
  const factory ActiveCurse({
    required String id,
    required String sessionId,
    required String cardId,
    required CurseType curseType,
    required DateTime startedAt,
    DateTime? expiresAt,
    @Default(false) bool isBlocking,
    String? condition, // What ends this curse
  }) = _ActiveCurse;

  factory ActiveCurse.fromJson(Map<String, dynamic> json) =>
      _$ActiveCurseFromJson(json);
}

@freezed
class PlacedTimeTrap with _$PlacedTimeTrap {
  const factory PlacedTimeTrap({
    required String id,
    required String sessionId,
    required String cardId,
    required String stationId,
    required String stationName,
    required double latitude,
    required double longitude,
    required DateTime placedAt,
    DateTime? triggeredAt,
    String? triggeredByParticipantId,
  }) = _PlacedTimeTrap;

  factory PlacedTimeTrap.fromJson(Map<String, dynamic> json) =>
      _$PlacedTimeTrapFromJson(json);
}

@freezed
class DeckState with _$DeckState {
  const factory DeckState({
    required String sessionId,
    required List<String> drawPile, // Card IDs in order
    required List<String> discardPile,
    required int totalCardsDrawn,
  }) = _DeckState;

  factory DeckState.fromJson(Map<String, dynamic> json) =>
      _$DeckStateFromJson(json);
}

extension ActiveCurseX on ActiveCurse {
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Duration? get remainingDuration {
    if (expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

extension GameCardX on GameCard {
  bool get isTimeBonus => type == CardType.timeBonus;
  bool get isPowerup => type == CardType.powerup;
  bool get isCurse => type == CardType.curse;
  bool get isTimeTrap => type == CardType.timeTrap;

  Duration? get timeBonusDuration {
    if (timeBonusMinutes != null) {
      return Duration(minutes: timeBonusMinutes!);
    }
    return null;
  }
}
