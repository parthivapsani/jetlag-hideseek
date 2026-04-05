import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_event.freezed.dart';
part 'game_event.g.dart';

@freezed
class GameEvent with _$GameEvent {
  const factory GameEvent({
    required String id,
    required String sessionId,
    String? roundId,
    required String eventType,
    @Default({}) Map<String, dynamic> payload,
    DateTime? createdAt,
  }) = _GameEvent;

  factory GameEvent.fromJson(Map<String, dynamic> json) =>
      _$GameEventFromJson(json);
}
