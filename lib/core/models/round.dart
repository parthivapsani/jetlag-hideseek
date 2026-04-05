import 'package:freezed_annotation/freezed_annotation.dart';

part 'round.freezed.dart';
part 'round.g.dart';

enum RoundStatus {
  @JsonValue('waiting')
  waiting,
  @JsonValue('hiding')
  hiding,
  @JsonValue('seeking')
  seeking,
  @JsonValue('endgame')
  endgame,
  @JsonValue('found')
  found,
}

@freezed
class Round with _$Round {
  const Round._();

  const factory Round({
    required String id,
    required String sessionId,
    @Default(1) int roundNumber,
    String? hiderTeamId,
    String? seekerTeamId,
    @Default(RoundStatus.waiting) RoundStatus status,
    DateTime? hidingStartedAt,
    DateTime? seekingStartedAt,
    DateTime? timerPausedAt,
    int? pausedTimeRemainingSeconds,
    DateTime? foundAt,
    int? hideDurationSeconds,
    DateTime? createdAt,
  }) = _Round;

  factory Round.fromJson(Map<String, dynamic> json) => _$RoundFromJson(json);

  bool get isActive => status != RoundStatus.found;

  Duration? get hideDuration => hideDurationSeconds != null
      ? Duration(seconds: hideDurationSeconds!)
      : null;
}
