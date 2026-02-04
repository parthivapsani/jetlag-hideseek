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
// Card rewards: Matching/Measuring (Draw 3 Keep 1), Radar/Thermometer (Draw 2 Keep 1),
//               Tentacles (Draw 4 Keep 2), Photo (Draw 1)

const _allQuestions = <Question>[
  // === MATCHING (Draw 3, Keep 1) ===
  // "Is your something the same as our something?"
  Question(
    id: 'match_1',
    text: 'Is your closest [type of place] the same as our closest [type of place]?',
    category: QuestionCategory.matching,
    cardsDraw: 3,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Compare your closest instance of the specified place type to the seekers\' closest. Answer yes if they match, no if different.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'match_2',
    text: 'Is your closest transit station the same as our closest transit station?',
    category: QuestionCategory.matching,
    cardsDraw: 3,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Compare your closest transit station to the seekers\' closest. Answer yes if they match.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'match_3',
    text: 'Is your closest [landmark type] the same as our closest [landmark type]?',
    category: QuestionCategory.matching,
    cardsDraw: 3,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Compare your closest instance of the specified landmark to the seekers\' closest.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'match_4',
    text: 'Are you on the same transit line as us?',
    category: QuestionCategory.matching,
    cardsDraw: 3,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are currently on or at a station of the same transit line as the seekers.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'match_5',
    text: 'Is your closest [chain store/restaurant] the same as our closest?',
    category: QuestionCategory.matching,
    cardsDraw: 3,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Compare your closest branch of the specified chain to the seekers\' closest.',
    options: ['Yes', 'No'],
  ),

  // === MEASURING (Draw 3, Keep 1) ===
  // "Are you closer to something than we are?"
  Question(
    id: 'meas_1',
    text: 'Are you closer to [landmark/location] than we are?',
    category: QuestionCategory.measuring,
    cardsDraw: 3,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Compare your distance to the specified location versus the seekers\' distance. Answer yes if you are closer.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'meas_2',
    text: 'Are you closer to an airport than we are?',
    category: QuestionCategory.measuring,
    cardsDraw: 3,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Compare your distance to the nearest airport versus the seekers\' distance.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'meas_3',
    text: 'Are you closer to [body of water] than we are?',
    category: QuestionCategory.measuring,
    cardsDraw: 3,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Compare your distance to the specified body of water versus the seekers\' distance.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'meas_4',
    text: 'Are you closer to the city center than we are?',
    category: QuestionCategory.measuring,
    cardsDraw: 3,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Compare your distance to the agreed-upon city center versus the seekers\' distance.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'meas_5',
    text: 'Are you closer to [transit station] than we are?',
    category: QuestionCategory.measuring,
    cardsDraw: 3,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Compare your distance to the specified transit station versus the seekers\' distance.',
    options: ['Yes', 'No'],
  ),

  // === RADAR (Draw 2, Keep 1) ===
  // "Are you within X distance of our current location?"
  Question(
    id: 'rad_1',
    text: 'Are you within [X] meters/km of our current location?',
    category: QuestionCategory.radar,
    cardsDraw: 2,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'The seekers specify a distance. Answer yes if you are within that distance of their current position.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_2',
    text: 'Are you within 500 meters of our current location?',
    category: QuestionCategory.radar,
    cardsDraw: 2,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 500 meters of the seekers\' current position.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_3',
    text: 'Are you within 1 km of our current location?',
    category: QuestionCategory.radar,
    cardsDraw: 2,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 1 kilometer of the seekers\' current position.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_4',
    text: 'Are you within 2 km of our current location?',
    category: QuestionCategory.radar,
    cardsDraw: 2,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 2 kilometers of the seekers\' current position.',
    options: ['Yes', 'No'],
  ),
  Question(
    id: 'rad_5',
    text: 'Are you within 5 km of our current location?',
    category: QuestionCategory.radar,
    cardsDraw: 2,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.boolean,
    rules: 'Answer yes if you are within 5 kilometers of the seekers\' current position.',
    options: ['Yes', 'No'],
  ),

  // === THERMOMETER (Draw 2, Keep 1) ===
  // "We've moved X distance, are we warmer or colder?"
  Question(
    id: 'therm_1',
    text: 'We\'ve moved [X] meters/km. Are we warmer or colder?',
    category: QuestionCategory.thermometer,
    cardsDraw: 2,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Seekers specify how far they have moved. Compare their new position to their old position relative to you. Answer warmer if closer, colder if farther.',
    options: ['Warmer', 'Colder'],
  ),
  Question(
    id: 'therm_2',
    text: 'We\'ve moved 500 meters. Are we warmer or colder?',
    category: QuestionCategory.thermometer,
    cardsDraw: 2,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Compare the seekers\' new position to their old position. Answer warmer if they are now closer to you.',
    options: ['Warmer', 'Colder'],
  ),
  Question(
    id: 'therm_3',
    text: 'We\'ve moved 1 km. Are we warmer or colder?',
    category: QuestionCategory.thermometer,
    cardsDraw: 2,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Compare the seekers\' new position to their old position. Answer warmer if they are now closer to you.',
    options: ['Warmer', 'Colder'],
  ),

  // === TENTACLES (Draw 4, Keep 2) ===
  // "Of all the [something] within X radius, which is your closest?"
  Question(
    id: 'tent_1',
    text: 'Of all the [type of place] within [X] km radius of us, which is your closest?',
    category: QuestionCategory.tentacles,
    cardsDraw: 4,
    cardsKeep: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Seekers define a radius around their position and a type of place. You must name which of those places within their radius is closest to you.',
  ),
  Question(
    id: 'tent_2',
    text: 'Of all the transit stations within 2 km of us, which is your closest?',
    category: QuestionCategory.tentacles,
    cardsDraw: 4,
    cardsKeep: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Name which transit station within 2 km of the seekers is closest to your position.',
  ),
  Question(
    id: 'tent_3',
    text: 'Of all the [landmarks] within 5 km of us, which is your closest?',
    category: QuestionCategory.tentacles,
    cardsDraw: 4,
    cardsKeep: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Name which of the specified landmarks within 5 km of the seekers is closest to your position.',
  ),
  Question(
    id: 'tent_4',
    text: 'Of all the libraries within 3 km of us, which is your closest?',
    category: QuestionCategory.tentacles,
    cardsDraw: 4,
    cardsKeep: 2,
    responseTimeMinutes: 5,
    answerType: AnswerType.text,
    rules: 'Name which library within 3 km of the seekers is closest to your position.',
  ),

  // === PHOTO (Draw 1) ===
  // "Send us a picture of something"
  Question(
    id: 'photo_1',
    text: 'Send us a picture of the nearest [type of thing].',
    category: QuestionCategory.photo,
    cardsDraw: 1,
    cardsKeep: 1,
    responseTimeMinutes: 15,
    answerType: AnswerType.photo,
    rules: 'Take and send a photo of the nearest instance of the specified thing. The subject must be clearly visible.',
    requiresLocation: true,
  ),
  Question(
    id: 'photo_2',
    text: 'Send us a picture of the largest building visible from your station.',
    category: QuestionCategory.photo,
    cardsDraw: 1,
    cardsKeep: 1,
    responseTimeMinutes: 15,
    answerType: AnswerType.photo,
    rules: 'Photograph the largest building you can see from your current transit station.',
    requiresLocation: true,
  ),
  Question(
    id: 'photo_3',
    text: 'Send us a picture of your station sign.',
    category: QuestionCategory.photo,
    cardsDraw: 1,
    cardsKeep: 1,
    responseTimeMinutes: 10,
    answerType: AnswerType.photo,
    rules: 'Take a photo showing the name of your current transit station. The name must be clearly visible.',
    requiresLocation: true,
  ),
  Question(
    id: 'photo_4',
    text: 'Send us a picture of the nearest street sign.',
    category: QuestionCategory.photo,
    cardsDraw: 1,
    cardsKeep: 1,
    responseTimeMinutes: 10,
    answerType: AnswerType.photo,
    rules: 'Take a photo showing a street sign near you. The street name must be clearly visible.',
    requiresLocation: true,
  ),
  Question(
    id: 'photo_5',
    text: 'Send us a picture of your current view.',
    category: QuestionCategory.photo,
    cardsDraw: 1,
    cardsKeep: 1,
    responseTimeMinutes: 5,
    answerType: AnswerType.photo,
    rules: 'Take a photo showing your current surroundings.',
    requiresLocation: true,
  ),
];
