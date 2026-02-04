import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'game_provider.dart';
import 'card_provider.dart';

// ============ Timer State ============

class TimerState {
  final Duration elapsed;
  final Duration remaining;
  final Duration effectiveTotal;
  final bool isPaused;
  final bool isExpired;
  final TimerPhase phase;

  const TimerState({
    required this.elapsed,
    required this.remaining,
    required this.effectiveTotal,
    required this.isPaused,
    required this.isExpired,
    required this.phase,
  });

  factory TimerState.initial() => const TimerState(
        elapsed: Duration.zero,
        remaining: Duration.zero,
        effectiveTotal: Duration.zero,
        isPaused: false,
        isExpired: false,
        phase: TimerPhase.waiting,
      );
}

enum TimerPhase {
  waiting,
  hiding,
  seeking,
  ended,
}

// ============ Timer Provider ============

final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier(ref);
});

class TimerNotifier extends StateNotifier<TimerState> {
  final Ref _ref;
  Timer? _timer;

  TimerNotifier(this._ref) : super(TimerState.initial()) {
    // Listen to session changes
    _ref.listen(currentSessionProvider, (previous, next) {
      _updateFromSession(next.valueOrNull);
    });
  }

  void _updateFromSession(GameSession? session) {
    if (session == null) {
      _stopTimer();
      state = TimerState.initial();
      return;
    }

    final effectiveTotal = _ref.read(effectiveHidingTimeProvider);

    switch (session.status) {
      case SessionStatus.waiting:
        _stopTimer();
        state = TimerState(
          elapsed: Duration.zero,
          remaining: effectiveTotal,
          effectiveTotal: effectiveTotal,
          isPaused: false,
          isExpired: false,
          phase: TimerPhase.waiting,
        );
        break;

      case SessionStatus.hiding:
        if (session.hidingStartedAt != null) {
          _startTimer(session, effectiveTotal);
        }
        break;

      case SessionStatus.seeking:
        _startSeekingTimer(session);
        break;

      case SessionStatus.paused:
        _stopTimer();
        final remaining = session.pausedTimeRemainingSeconds != null
            ? Duration(seconds: session.pausedTimeRemainingSeconds!)
            : state.remaining;
        state = TimerState(
          elapsed: effectiveTotal - remaining,
          remaining: remaining,
          effectiveTotal: effectiveTotal,
          isPaused: true,
          isExpired: false,
          phase: state.phase,
        );
        break;

      case SessionStatus.ended:
        _stopTimer();
        state = TimerState(
          elapsed: state.elapsed,
          remaining: Duration.zero,
          effectiveTotal: effectiveTotal,
          isPaused: false,
          isExpired: true,
          phase: TimerPhase.ended,
        );
        break;
    }
  }

  void _startTimer(GameSession session, Duration effectiveTotal) {
    _stopTimer();

    void updateState() {
      if (session.hidingStartedAt == null) return;

      final elapsed = DateTime.now().difference(session.hidingStartedAt!);
      final remaining = effectiveTotal - elapsed;

      if (remaining.isNegative) {
        state = TimerState(
          elapsed: effectiveTotal,
          remaining: Duration.zero,
          effectiveTotal: effectiveTotal,
          isPaused: false,
          isExpired: true,
          phase: TimerPhase.hiding,
        );
        _stopTimer();
        return;
      }

      state = TimerState(
        elapsed: elapsed,
        remaining: remaining,
        effectiveTotal: effectiveTotal,
        isPaused: false,
        isExpired: false,
        phase: TimerPhase.hiding,
      );
    }

    updateState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => updateState());
  }

  void _startSeekingTimer(GameSession session) {
    _stopTimer();
    final effectiveTotal = _ref.read(effectiveHidingTimeProvider);

    void updateState() {
      if (session.seekingStartedAt == null) return;

      final seekingElapsed = DateTime.now().difference(session.seekingStartedAt!);

      state = TimerState(
        elapsed: seekingElapsed,
        remaining: Duration.zero,
        effectiveTotal: effectiveTotal,
        isPaused: false,
        isExpired: false,
        phase: TimerPhase.seeking,
      );
    }

    updateState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => updateState());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

// ============ Formatted Time ============

final formattedRemainingTimeProvider = Provider<String>((ref) {
  final timer = ref.watch(timerProvider);
  return _formatDuration(timer.remaining);
});

final formattedElapsedTimeProvider = Provider<String>((ref) {
  final timer = ref.watch(timerProvider);
  return _formatDuration(timer.elapsed);
});

final formattedEffectiveTimeProvider = Provider<String>((ref) {
  final timer = ref.watch(timerProvider);
  return _formatDuration(timer.effectiveTotal);
});

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes}:${seconds.toString().padLeft(2, '0')}';
}

// ============ Question Deadline Timer ============

final questionDeadlineProvider =
    Provider.family<Duration?, String>((ref, sessionQuestionId) {
  final questions = ref.watch(sessionQuestionsProvider).valueOrNull ?? [];
  final question = questions.where((q) => q.id == sessionQuestionId).firstOrNull;
  if (question == null) return null;

  final remaining = question.responseDeadline.difference(DateTime.now());
  return remaining.isNegative ? Duration.zero : remaining;
});

// Auto-updating provider for active question deadline
final activeQuestionDeadlineProvider = StreamProvider<Duration?>((ref) {
  final questions = ref.watch(sessionQuestionsProvider).valueOrNull ?? [];
  final pending = questions.where((q) => q.status == QuestionStatus.asked).firstOrNull;

  if (pending == null) return Stream.value(null);

  return Stream.periodic(const Duration(seconds: 1), (_) {
    final remaining = pending.responseDeadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  });
});

// We need this import for sessionQuestionsProvider
import 'question_provider.dart';
