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

const _allQuestions = <Question>[
  // === RELATIVE (40 coins, 2 cards, 5 min) ===
  Question(
    id: 'rel_1',
    text: 'Are you north or south of [landmark]?',
    category: QuestionCategory.relative,
    coinCost: 40,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.direction,
    rules: 'The hider must answer truthfully based on their current position relative to the specified landmark.',
    options: ['North', 'South'],
  ),
  Question(
    id: 'rel_2',
    text: 'Are you east or west of [landmark]?',
    category: QuestionCategory.relative,
    coinCost: 40,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.direction,
    rules: 'The hider must answer truthfully based on their current position relative to the specified landmark.',
    options: ['East', 'West'],
  ),
  Question(
    id: 'rel_3',
    text: 'Are you north or south of [street name]?',
    category: QuestionCategory.relative,
    coinCost: 40,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.direction,
    rules: 'The hider must answer truthfully based on their position relative to the specified street.',
    options: ['North', 'South'],
  ),
  Question(
    id: 'rel_4',
    text: 'Are you east or west of [street name]?',
    category: QuestionCategory.relative,
    coinCost: 40,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.direction,
    rules: 'The hider must answer truthfully based on their position relative to the specified street.',
    options: ['East', 'West'],
  ),
  Question(
    id: 'rel_5',
    text: 'Are you closer to [location A] or [location B]?',
    category: QuestionCategory.relative,
    coinCost: 40,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'The hider must answer which location they are closer to as the crow flies.',
  ),

  // === RADAR (30 coins, 2 cards, 5 min) ===
  Question(
    id: 'rad_1',
    text: 'Are you within 100 feet of a [type of place]?',
    category: QuestionCategory.radar,
    coinCost: 30,
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
    coinCost: 30,
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
    coinCost: 30,
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
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 0.5 miles of the specified type of place.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_5',
    text: 'Are you within 1 mile of a [type of place]?',
    category: QuestionCategory.radar,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 1 mile of the specified type of place.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_6',
    text: 'Are you within 5 miles of [specific location]?',
    category: QuestionCategory.radar,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 5 miles of the specified location.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_7',
    text: 'Are you within 10 miles of [specific location]?',
    category: QuestionCategory.radar,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 10 miles of the specified location.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_8',
    text: 'Are you within 25 miles of [specific location]?',
    category: QuestionCategory.radar,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 25 miles of the specified location.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_9',
    text: 'Are you within 50 miles of [specific location]?',
    category: QuestionCategory.radar,
    coinCost: 30,
    cardsDrawn: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 50 miles of the specified location.',
    options: ['Yes', 'No'],
  ),

  // === PHOTO (15 coins, 1 card, 10-20 min) ===
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
    text: 'Send a photo looking down the nearest major street.',
    category: QuestionCategory.photo,
    coinCost: 15,
    cardsDrawn: 1,
    responseTimeMinutes: 10,
    answerType: AnswerType.photo,
    rules: 'Take a photo looking down a major street to show the surroundings.',
    requiresLocation: true,
  ),
  Question(
    id: 'photo_6',
    text: 'Send a photo of your current view.',
    category: QuestionCategory.photo,
    coinCost: 15,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.photo,
    rules: 'Take a photo showing your current surroundings.',
    requiresLocation: true,
  ),

  // === ODDBALL (10 coins, 1 card, 5 min) ===
  Question(
    id: 'odd_1',
    text: 'FaceTime us and show us a bird.',
    category: QuestionCategory.oddball,
    coinCost: 10,
    cardsDrawn: 1,
    responseTimeMinutes: 10,
    answerType: AnswerType.text,
    rules: 'Start a video call and show a live bird (not a picture). Can be any bird - pigeon, sparrow, etc.',
  ),
  Question(
    id: 'odd_2',
    text: 'Send an audio recording of the ambient sounds around you.',
    category: QuestionCategory.oddball,
    coinCost: 10,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.audio,
    rules: 'Record 30 seconds of ambient sound from your current location.',
  ),
  Question(
    id: 'odd_3',
    text: 'Send an audio recording of a train or transit announcement.',
    category: QuestionCategory.oddball,
    coinCost: 10,
    cardsDrawn: 1,
    responseTimeMinutes: 15,
    answerType: AnswerType.audio,
    rules: 'Record audio of a transit announcement or train sounds.',
  ),
  Question(
    id: 'odd_4',
    text: 'Tell us something interesting you can see right now.',
    category: QuestionCategory.oddball,
    coinCost: 10,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Describe something notable or unusual that you can currently see.',
  ),
  Question(
    id: 'odd_5',
    text: 'What is the most common color of car you can see?',
    category: QuestionCategory.oddball,
    coinCost: 10,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Look around and report the most common car color visible from your position.',
  ),

  // === PRECISION (10 coins, 1 card, 5 min) ===
  Question(
    id: 'prec_1',
    text: 'What street are you on or nearest to?',
    category: QuestionCategory.precision,
    coinCost: 10,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Name the street you are currently on or the nearest street to your position.',
    requiresLocation: true,
  ),
  Question(
    id: 'prec_2',
    text: 'What is the nearest cross street?',
    category: QuestionCategory.precision,
    coinCost: 10,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Name the nearest street intersection.',
    requiresLocation: true,
  ),
  Question(
    id: 'prec_3',
    text: 'What transit line are you on or nearest to?',
    category: QuestionCategory.precision,
    coinCost: 10,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Name the transit line (subway, bus, etc.) you are on or nearest to.',
    requiresLocation: true,
  ),
  Question(
    id: 'prec_4',
    text: 'What is the name of the nearest transit station?',
    category: QuestionCategory.precision,
    coinCost: 10,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Name the nearest transit station to your current position.',
    requiresLocation: true,
  ),
  Question(
    id: 'prec_5',
    text: 'What neighborhood or district are you in?',
    category: QuestionCategory.precision,
    coinCost: 10,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Name the neighborhood, district, or area you are currently in.',
    requiresLocation: true,
  ),
  Question(
    id: 'prec_6',
    text: 'What is the address of the nearest building?',
    category: QuestionCategory.precision,
    coinCost: 10,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Provide the street address of the nearest building.',
    requiresLocation: true,
  ),
  Question(
    id: 'prec_7',
    text: 'What direction is the nearest body of water?',
    category: QuestionCategory.precision,
    coinCost: 10,
    cardsDrawn: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.direction,
    rules: 'Indicate the cardinal direction (N, S, E, W, NE, etc.) to the nearest body of water.',
    options: ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'],
  ),
];
