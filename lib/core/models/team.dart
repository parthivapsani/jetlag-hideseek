import 'package:freezed_annotation/freezed_annotation.dart';

part 'team.freezed.dart';
part 'team.g.dart';

@freezed
class Team with _$Team {
  const factory Team({
    required String id,
    required String sessionId,
    required String name,
    @Default('green') String color,
    @Default(0) int displayOrder,
    DateTime? createdAt,
  }) = _Team;

  factory Team.fromJson(Map<String, dynamic> json) => _$TeamFromJson(json);
}
