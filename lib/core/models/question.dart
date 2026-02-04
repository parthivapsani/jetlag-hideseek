import 'package:freezed_annotation/freezed_annotation.dart';

part 'question.freezed.dart';
part 'question.g.dart';

enum QuestionCategory {
  @JsonValue('matching')
  matching,
  @JsonValue('measuring')
  measuring,
  @JsonValue('radar')
  radar,
  @JsonValue('thermometer')
  thermometer,
  @JsonValue('tentacles')
  tentacles,
  @JsonValue('photo')
  photo,
}

enum QuestionStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('asked')
  asked,
  @JsonValue('answered')
  answered,
  @JsonValue('expired')
  expired,
  @JsonValue('vetoed')
  vetoed,
}

enum AnswerType {
  @JsonValue('text')
  text,
  @JsonValue('photo')
  photo,
  @JsonValue('audio')
  audio,
  @JsonValue('boolean')
  boolean,
  @JsonValue('number')
  number,
  @JsonValue('direction')
  direction,
}

@freezed
class Question with _$Question {
  const factory Question({
    required String id,
    required String text,
    required QuestionCategory category,
    required int coinCost,
    required int cardsDrawn,
    required int responseTimeMinutes,
    required AnswerType answerType,
    String? answerHint,
    String? rules,
    @Default(false) bool requiresLocation,
    @Default(false) bool canBeVetoed,
    List<String>? options, // For multiple choice
  }) = _Question;

  factory Question.fromJson(Map<String, dynamic> json) =>
      _$QuestionFromJson(json);
}

@freezed
class SessionQuestion with _$SessionQuestion {
  const factory SessionQuestion({
    required String id,
    required String sessionId,
    required String questionId,
    required QuestionCategory category,
    required QuestionStatus status,
    required String askedByParticipantId,
    required DateTime askedAt,
    DateTime? answeredAt,
    required DateTime responseDeadline,
    String? answerText,
    String? answerPhotoUrl,
    String? answerAudioUrl,
    @Default(false) bool wasTestMode,
  }) = _SessionQuestion;

  factory SessionQuestion.fromJson(Map<String, dynamic> json) =>
      _$SessionQuestionFromJson(json);
}

@freezed
class CategoryCooldown with _$CategoryCooldown {
  const factory CategoryCooldown({
    required QuestionCategory category,
    required DateTime lastAskedAt,
    required DateTime cooldownEndsAt,
  }) = _CategoryCooldown;

  factory CategoryCooldown.fromJson(Map<String, dynamic> json) =>
      _$CategoryCooldownFromJson(json);
}

extension QuestionCategoryX on QuestionCategory {
  String get displayName {
    switch (this) {
      case QuestionCategory.matching:
        return 'Matching';
      case QuestionCategory.measuring:
        return 'Measuring';
      case QuestionCategory.radar:
        return 'Radar';
      case QuestionCategory.thermometer:
        return 'Thermometer';
      case QuestionCategory.tentacles:
        return 'Tentacles';
      case QuestionCategory.photo:
        return 'Photo';
    }
  }

  int get defaultCoinCost {
    switch (this) {
      case QuestionCategory.matching:
        return 30;
      case QuestionCategory.measuring:
        return 30;
      case QuestionCategory.radar:
        return 25;
      case QuestionCategory.thermometer:
        return 20;
      case QuestionCategory.tentacles:
        return 20;
      case QuestionCategory.photo:
        return 15;
    }
  }

  int get cardsDrawn {
    switch (this) {
      case QuestionCategory.matching:
        return 2;
      case QuestionCategory.measuring:
        return 2;
      case QuestionCategory.radar:
        return 2;
      case QuestionCategory.thermometer:
        return 1;
      case QuestionCategory.tentacles:
        return 1;
      case QuestionCategory.photo:
        return 1;
    }
  }

  int get defaultResponseTimeMinutes {
    switch (this) {
      case QuestionCategory.matching:
        return 5;
      case QuestionCategory.measuring:
        return 5;
      case QuestionCategory.radar:
        return 5;
      case QuestionCategory.thermometer:
        return 5;
      case QuestionCategory.tentacles:
        return 5;
      case QuestionCategory.photo:
        return 15;
    }
  }

  Duration get cooldownDuration => const Duration(minutes: 30);
}
