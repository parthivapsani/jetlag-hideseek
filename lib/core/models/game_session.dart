import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_session.freezed.dart';
part 'game_session.g.dart';

enum SessionStatus {
  @JsonValue('waiting')
  waiting,
  @JsonValue('hiding')
  hiding,
  @JsonValue('seeking')
  seeking,
  @JsonValue('paused')
  paused,
  @JsonValue('ended')
  ended,
}

enum ParticipantRole {
  @JsonValue('hider')
  hider,
  @JsonValue('seeker')
  seeker,
  @JsonValue('spectator')
  spectator,
}

@freezed
class GameSession with _$GameSession {
  const factory GameSession({
    required String id,
    required String roomCode,
    required SessionStatus status,
    required String gameAreaId,
    @Default(3600) int hidingPeriodSeconds, // 1 hour default
    @Default(804.672) double zoneRadiusMeters, // 0.5 miles
    DateTime? hidingStartedAt,
    DateTime? seekingStartedAt,
    DateTime? timerPausedAt,
    int? pausedTimeRemainingSeconds,
    DateTime? endedAt,
    String? winnerId,
    required String createdBy,
    required DateTime createdAt,
  }) = _GameSession;

  factory GameSession.fromJson(Map<String, dynamic> json) =>
      _$GameSessionFromJson(json);
}

@freezed
class Participant with _$Participant {
  const factory Participant({
    required String id,
    required String sessionId,
    String? userId,
    required String displayName,
    required ParticipantRole role,
    required String deviceToken,
    @Default(false) bool isConnected,
    @Default(false) bool isHost,
    double? lastLocationLat,
    double? lastLocationLng,
    DateTime? lastLocationAt,
    DateTime? joinedAt,
  }) = _Participant;

  factory Participant.fromJson(Map<String, dynamic> json) =>
      _$ParticipantFromJson(json);
}

extension GameSessionX on GameSession {
  bool get isActive =>
      status == SessionStatus.hiding || status == SessionStatus.seeking;

  Duration get hidingPeriodDuration => Duration(seconds: hidingPeriodSeconds);

  Duration? get elapsedHidingTime {
    if (hidingStartedAt == null) return null;
    if (status == SessionStatus.paused && pausedTimeRemainingSeconds != null) {
      return hidingPeriodDuration -
          Duration(seconds: pausedTimeRemainingSeconds!);
    }
    return DateTime.now().difference(hidingStartedAt!);
  }

  Duration? get remainingHidingTime {
    if (hidingStartedAt == null) return null;
    if (status == SessionStatus.paused && pausedTimeRemainingSeconds != null) {
      return Duration(seconds: pausedTimeRemainingSeconds!);
    }
    final elapsed = DateTime.now().difference(hidingStartedAt!);
    final remaining = hidingPeriodDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration? get elapsedSeekingTime {
    if (seekingStartedAt == null) return null;
    return DateTime.now().difference(seekingStartedAt!);
  }
}
