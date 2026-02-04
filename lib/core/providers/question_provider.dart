import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'game_provider.dart';

// ============ Question Data ============

/// All available questions
final allQuestionsProvider = Provider<List<Question>>((ref) {
  return _allQuestions;
});

/// Questions filtered by category
final questionsByCategoryProvider =
    Provider.family<List<Question>, QuestionCategory>((ref, category) {
  final questions = ref.watch(allQuestionsProvider);
  return questions.where((q) => q.category == category).toList();
});

// ============ Session Questions ============

final sessionQuestionsProvider = StreamProvider<List<SessionQuestion>>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) return Stream.value([]);

  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);

  return _questionsStream(service, realtime, sessionId);
});

Stream<List<SessionQuestion>> _questionsStream(
  SupabaseService service,
  RealtimeService realtime,
  String sessionId,
) async* {
  yield await service.getSessionQuestions(sessionId);

  // Combine new questions and updates
  final newQuestions = realtime.subscribeToNewQuestions(sessionId);
  final updates = realtime.subscribeToQuestionUpdates(sessionId);

  final questionsMap = <String, SessionQuestion>{};
  final initial = await service.getSessionQuestions(sessionId);
  for (final q in initial) {
    questionsMap[q.id] = q;
  }

  await for (final question in newQuestions.asBroadcastStream().merge(updates)) {
    questionsMap[question.id] = question;
    yield questionsMap.values.toList()
      ..sort((a, b) => b.askedAt.compareTo(a.askedAt));
  }
}

extension<T> on Stream<T> {
  Stream<T> merge(Stream<T> other) {
    final controller = StreamController<T>.broadcast();
    listen((event) => controller.add(event));
    other.listen((event) => controller.add(event));
    return controller.stream;
  }
}

/// Pending questions (asked but not answered)
final pendingQuestionsProvider = Provider<List<SessionQuestion>>((ref) {
  final questions = ref.watch(sessionQuestionsProvider).valueOrNull ?? [];
  return questions
      .where((q) => q.status == QuestionStatus.asked)
      .toList();
});

/// Current question being answered (for hider)
final currentQuestionProvider = Provider<SessionQuestion?>((ref) {
  final pending = ref.watch(pendingQuestionsProvider);
  if (pending.isEmpty) return null;
  return pending.first; // Most recent pending question
});

// ============ Category Cooldowns ============

final categoryCooldownsProvider = Provider<Map<QuestionCategory, DateTime>>((ref) {
  final questions = ref.watch(sessionQuestionsProvider).valueOrNull ?? [];
  final cooldowns = <QuestionCategory, DateTime>{};

  for (final category in QuestionCategory.values) {
    final categoryQuestions = questions
        .where((q) => q.category == category && !q.wasTestMode)
        .toList();

    if (categoryQuestions.isNotEmpty) {
      final lastAsked = categoryQuestions
          .map((q) => q.askedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final cooldownEnd = lastAsked.add(category.cooldownDuration);
      if (cooldownEnd.isAfter(DateTime.now())) {
        cooldowns[category] = cooldownEnd;
      }
    }
  }

  return cooldowns;
});

final isCategoryOnCooldownProvider =
    Provider.family<bool, QuestionCategory>((ref, category) {
  final cooldowns = ref.watch(categoryCooldownsProvider);
  final cooldownEnd = cooldowns[category];
  if (cooldownEnd == null) return false;
  return cooldownEnd.isAfter(DateTime.now());
});

final categoryRemainingCooldownProvider =
    Provider.family<Duration?, QuestionCategory>((ref, category) {
  final cooldowns = ref.watch(categoryCooldownsProvider);
  final cooldownEnd = cooldowns[category];
  if (cooldownEnd == null) return null;
  final remaining = cooldownEnd.difference(DateTime.now());
  return remaining.isNegative ? null : remaining;
});

// ============ Test Mode ============

final testModeProvider = StateProvider<bool>((ref) => false);

// ============ Question Actions ============

final questionActionsProvider = Provider<QuestionActions>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return QuestionActions(ref, service);
});

class QuestionActions {
  final Ref _ref;
  final SupabaseService _service;

  QuestionActions(this._ref, this._service);

  Future<SessionQuestion> askQuestion({
    required String questionId,
    required QuestionCategory category,
    required int responseTimeMinutes,
  }) async {
    final sessionId = _ref.read(currentSessionIdProvider);
    final participantId = _ref.read(currentParticipantIdProvider);
    final testMode = _ref.read(testModeProvider);

    if (sessionId == null || participantId == null) {
      throw Exception('No active session or participant');
    }

    // Check cooldown (skip for test mode)
    if (!testMode) {
      final isOnCooldown = _ref.read(isCategoryOnCooldownProvider(category));
      if (isOnCooldown) {
        throw Exception('Category is on cooldown');
      }
    }

    return await _service.askQuestion(
      sessionId: sessionId,
      questionId: questionId,
      category: category,
      askedByParticipantId: participantId,
      responseTimeMinutes: responseTimeMinutes,
      testMode: testMode,
    );
  }

  Future<void> answerQuestion(
    String sessionQuestionId, {
    String? answerText,
    String? answerPhotoUrl,
    String? answerAudioUrl,
  }) async {
    await _service.answerQuestion(
      sessionQuestionId,
      answerText: answerText,
      answerPhotoUrl: answerPhotoUrl,
      answerAudioUrl: answerAudioUrl,
    );
  }

  Future<void> vetoQuestion(String sessionQuestionId) async {
    await _service.vetoQuestion(sessionQuestionId);
  }
}

// ============ Question Database ============
// Categories: Matching, Measuring, Radar, Thermometer, Tentacles, Photo

const _allQuestions = <Question>[
  // === MATCHING (30 coins, 2 cards, 5 min) ===
  // Seekers name multiple options, hider says which one matches
  Question(
    id: 'match_1',
    text: 'Which of these transit lines are you on or nearest to: [line A], [line B], [line C]?',
    category: QuestionCategory.matching,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Seekers name 2-4 transit lines. The hider must say which one they are on or nearest to. If none apply, hider says "none".',
  ),
  Question(
    id: 'match_2',
    text: 'Which of these neighborhoods are you in: [A], [B], [C]?',
    category: QuestionCategory.matching,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Seekers name 2-4 neighborhoods or districts. The hider must say which one they are in. If none apply, hider says "none".',
  ),
  Question(
    id: 'match_3',
    text: 'Which of these streets are you on or nearest to: [A], [B], [C]?',
    category: QuestionCategory.matching,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Seekers name 2-4 streets. The hider must say which one they are on or nearest to. If none apply, hider says "none".',
  ),
  Question(
    id: 'match_4',
    text: 'Which of these stations are you at or nearest to: [A], [B], [C]?',
    category: QuestionCategory.matching,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Seekers name 2-4 transit stations. The hider must say which one they are at or nearest to. If none apply, hider says "none".',
  ),
  Question(
    id: 'match_5',
    text: 'Which of these landmarks are you closest to: [A], [B], [C]?',
    category: QuestionCategory.matching,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Seekers name 2-4 landmarks. The hider must say which one they are closest to.',
  ),

  // === MEASURING (30 coins, 2 cards, 5 min) ===
  // Distance/direction relative to specific locations
  Question(
    id: 'meas_1',
    text: 'How far are you from [landmark]?',
    category: QuestionCategory.measuring,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'The hider must estimate their distance from the specified landmark as the crow flies. Answer in approximate distance (e.g., "about 2 miles").',
  ),
  Question(
    id: 'meas_2',
    text: 'What direction is [landmark] from you?',
    category: QuestionCategory.measuring,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.direction,
    rules: 'The hider must give the cardinal or intercardinal direction to the specified landmark.',
    options: ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'],
  ),
  Question(
    id: 'meas_3',
    text: 'Are you north or south of [landmark/street]?',
    category: QuestionCategory.measuring,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.direction,
    rules: 'The hider must answer truthfully based on their position.',
    options: ['North', 'South'],
  ),
  Question(
    id: 'meas_4',
    text: 'Are you east or west of [landmark/street]?',
    category: QuestionCategory.measuring,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.direction,
    rules: 'The hider must answer truthfully based on their position.',
    options: ['East', 'West'],
  ),
  Question(
    id: 'meas_5',
    text: 'Are you closer to [location A] or [location B]?',
    category: QuestionCategory.measuring,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'The hider must answer which location they are closer to as the crow flies.',
  ),
  Question(
    id: 'meas_6',
    text: 'How many transit stops are you from [station]?',
    category: QuestionCategory.measuring,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.number,
    rules: 'Count the number of stops on the most direct transit route to the named station.',
  ),

  // === RADAR (25 coins, 2 cards, 5 min) ===
  // Yes/no within distance questions
  Question(
    id: 'rad_1',
    text: 'Are you within 100 feet of a [type of place]?',
    category: QuestionCategory.radar,
    coinCost: 25,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 100 feet of the specified type of place.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_2',
    text: 'Are you within 500 feet of a [type of place]?',
    category: QuestionCategory.radar,
    coinCost: 25,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 500 feet of the specified type of place.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_3',
    text: 'Are you within 0.25 miles of a [type of place]?',
    category: QuestionCategory.radar,
    coinCost: 25,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 0.25 miles of the specified type of place.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_4',
    text: 'Are you within 0.5 miles of a [type of place]?',
    category: QuestionCategory.radar,
    coinCost: 25,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 0.5 miles of the specified type of place.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_5',
    text: 'Are you within 1 mile of [specific location]?',
    category: QuestionCategory.radar,
    coinCost: 25,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 1 mile of the specified location.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_6',
    text: 'Are you within 2 miles of [specific location]?',
    category: QuestionCategory.radar,
    coinCost: 25,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 2 miles of the specified location.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_7',
    text: 'Are you within 5 miles of [specific location]?',
    category: QuestionCategory.radar,
    coinCost: 25,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 5 miles of the specified location.',
    options: ['Yes', 'No'],
  ),

  // === THERMOMETER (20 coins, 1 card, 5 min) ===
  // Hot/cold relative to a guess
  Question(
    id: 'therm_1',
    text: 'We guess you are at [location]. Hot or cold?',
    category: QuestionCategory.thermometer,
    coinCost: 20,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Hider answers "hot" if within ~0.5 miles, "warm" if within ~1 mile, "cold" if farther. Use your judgment for the exact thresholds.',
    options: ['Hot', 'Warm', 'Cold'],
  ),
  Question(
    id: 'therm_2',
    text: 'Are we getting warmer or colder compared to our last guess?',
    category: QuestionCategory.thermometer,
    coinCost: 20,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Compare current seeker position to their previous position relative to hider. Answer warmer, colder, or about the same.',
    options: ['Warmer', 'Colder', 'Same'],
  ),
  Question(
    id: 'therm_3',
    text: 'On a scale of 1-10, how close are we to you?',
    category: QuestionCategory.thermometer,
    coinCost: 20,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.number,
    rules: '1 = very far, 10 = very close. Hider estimates based on seeker position.',
  ),

  // === TENTACLES (20 coins, 1 card, 5 min) ===
  // Seekers draw lines/shapes, hider says if they cross them
  Question(
    id: 'tent_1',
    text: 'We draw a line from [point A] to [point B]. Are you north or south of this line?',
    category: QuestionCategory.tentacles,
    coinCost: 20,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.direction,
    rules: 'Seekers define a line between two points. Hider must say which side of the line they are on.',
    options: ['North', 'South'],
  ),
  Question(
    id: 'tent_2',
    text: 'We draw a line from [point A] to [point B]. Are you east or west of this line?',
    category: QuestionCategory.tentacles,
    coinCost: 20,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.direction,
    rules: 'Seekers define a line between two points. Hider must say which side of the line they are on.',
    options: ['East', 'West'],
  ),
  Question(
    id: 'tent_3',
    text: 'If we draw a circle with center [location] and radius [X miles], are you inside or outside?',
    category: QuestionCategory.tentacles,
    coinCost: 20,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Seekers define a circle. Hider must say if they are inside or outside the circle.',
    options: ['Inside', 'Outside'],
  ),
  Question(
    id: 'tent_4',
    text: 'We draw a box bounded by [streets/landmarks]. Are you inside or outside?',
    category: QuestionCategory.tentacles,
    coinCost: 20,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Seekers define a rectangular area. Hider must say if they are inside or outside.',
    options: ['Inside', 'Outside'],
  ),
  Question(
    id: 'tent_5',
    text: 'We extend a line from [location] heading [direction]. Do you cross this line going from [A] to [B]?',
    category: QuestionCategory.tentacles,
    coinCost: 20,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Complex geometry question. Hider determines if the described path crosses the line.',
    options: ['Yes', 'No'],
  ),

  // === PHOTO (15 coins, 1 card, 10-15 min) ===
  Question(
    id: 'photo_1',
    text: 'Send a photo of the nearest transit station sign.',
    category: QuestionCategory.photo,
    coinCost: 15,
    cardsDrawn: 1,
    responseTimeMinutes: 15,
    answerType: AnswerType.photo,
    rules: 'Take a photo showing the name of the nearest transit station. The station name must be clearly visible.',
    requiresLocation: true,
  ),
  Question(
    id: 'photo_2',
    text: 'Send a photo of the nearest street sign.',
    category: QuestionCategory.photo,
    coinCost: 15,
    cardsDrawn: 1,
    responseTimeMinutes: 10,
    answerType: AnswerType.photo,
    rules: 'Take a photo showing a street sign near you. The street name must be clearly visible.',
    requiresLocation: true,
  ),
  Question(
    id: 'photo_3',
    text: 'Send a photo of a distinctive landmark near you.',
    category: QuestionCategory.photo,
    coinCost: 15,
    cardsDrawn: 1,
    responseTimeMinutes: 10,
    answerType: AnswerType.photo,
    rules: 'Take a photo of a recognizable landmark that could help identify your location.',
    requiresLocation: true,
  ),
  Question(
    id: 'photo_4',
    text: 'Send a photo of the nearest business sign.',
    category: QuestionCategory.photo,
    coinCost: 15,
    cardsDrawn: 1,
    responseTimeMinutes: 10,
    answerType: AnswerType.photo,
    rules: 'Take a photo showing a business sign near you. The business name must be clearly visible.',
    requiresLocation: true,
  ),
  Question(
    id: 'photo_5',
    text: 'Send a photo of your current view.',
    category: QuestionCategory.photo,
    coinCost: 15,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.photo,
    rules: 'Take a photo showing your current surroundings.',
    requiresLocation: true,
  ),
  Question(
    id: 'photo_6',
    text: 'Send a photo of the transit map at your nearest station.',
    category: QuestionCategory.photo,
    coinCost: 15,
    cardsDrawn: 1,
    responseTimeMinutes: 15,
    answerType: AnswerType.photo,
    rules: 'Find and photograph a transit map that shows your current station.',
    requiresLocation: true,
  ),
];
