import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';

/// Reconstructed game state at a point in time.
class ReplayState {
  final DateTime scrubPosition;
  final String currentPhase;
  final List<GameEvent> visibleEvents;
  final List<GameEvent> questionEvents;
  final List<GameEvent> cardEvents;
  final List<GameEvent> locationEvents;
  final bool isPlaying;
  final double playbackSpeed;
  final DateTime? gameStart;
  final DateTime? gameEnd;

  const ReplayState({
    required this.scrubPosition,
    this.currentPhase = 'waiting',
    this.visibleEvents = const [],
    this.questionEvents = const [],
    this.cardEvents = const [],
    this.locationEvents = const [],
    this.isPlaying = false,
    this.playbackSpeed = 1.0,
    this.gameStart,
    this.gameEnd,
  });

  ReplayState copyWith({
    DateTime? scrubPosition,
    String? currentPhase,
    List<GameEvent>? visibleEvents,
    List<GameEvent>? questionEvents,
    List<GameEvent>? cardEvents,
    List<GameEvent>? locationEvents,
    bool? isPlaying,
    double? playbackSpeed,
    DateTime? gameStart,
    DateTime? gameEnd,
  }) {
    return ReplayState(
      scrubPosition: scrubPosition ?? this.scrubPosition,
      currentPhase: currentPhase ?? this.currentPhase,
      visibleEvents: visibleEvents ?? this.visibleEvents,
      questionEvents: questionEvents ?? this.questionEvents,
      cardEvents: cardEvents ?? this.cardEvents,
      locationEvents: locationEvents ?? this.locationEvents,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      gameStart: gameStart ?? this.gameStart,
      gameEnd: gameEnd ?? this.gameEnd,
    );
  }

  double get progress {
    if (gameStart == null || gameEnd == null) return 0.0;
    final total = gameEnd!.difference(gameStart!).inMilliseconds;
    if (total <= 0) return 0.0;
    final current = scrubPosition.difference(gameStart!).inMilliseconds;
    return (current / total).clamp(0.0, 1.0);
  }

  Duration get elapsed {
    if (gameStart == null) return Duration.zero;
    return scrubPosition.difference(gameStart!);
  }

  Duration get totalDuration {
    if (gameStart == null || gameEnd == null) return Duration.zero;
    return gameEnd!.difference(gameStart!);
  }
}

class ReplayController extends StateNotifier<ReplayState> {
  final List<GameEvent> _allEvents;
  Timer? _playbackTimer;

  ReplayController(this._allEvents) : super(_computeInitialState(_allEvents)) {
    _rebuild();
  }

  static ReplayState _computeInitialState(List<GameEvent> events) {
    if (events.isEmpty) return ReplayState(scrubPosition: DateTime.now());

    final sorted = List<GameEvent>.from(events)
      ..sort((a, b) => (a.createdAt ?? DateTime.now())
          .compareTo(b.createdAt ?? DateTime.now()));

    final start = sorted.first.createdAt ?? DateTime.now();
    final end = sorted.last.createdAt ?? DateTime.now();

    return ReplayState(
      scrubPosition: start,
      gameStart: start,
      gameEnd: end,
    );
  }

  void scrubTo(double progress) {
    if (state.gameStart == null || state.gameEnd == null) return;
    final total = state.gameEnd!.difference(state.gameStart!);
    final offset = Duration(milliseconds: (total.inMilliseconds * progress).round());
    state = state.copyWith(scrubPosition: state.gameStart!.add(offset));
    _rebuild();
  }

  void scrubToTime(DateTime time) {
    state = state.copyWith(scrubPosition: time);
    _rebuild();
  }

  void play() {
    if (state.isPlaying) return;
    state = state.copyWith(isPlaying: true);
    _startPlayback();
  }

  void pause() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    state = state.copyWith(isPlaying: false);
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void setSpeed(double speed) {
    state = state.copyWith(playbackSpeed: speed);
    if (state.isPlaying) {
      _playbackTimer?.cancel();
      _startPlayback();
    }
  }

  void _startPlayback() {
    _playbackTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) {
        if (state.gameEnd == null) return;
        final advance = Duration(
          milliseconds: (50 * state.playbackSpeed).round(),
        );
        final newPos = state.scrubPosition.add(advance);
        if (newPos.isAfter(state.gameEnd!)) {
          pause();
          state = state.copyWith(scrubPosition: state.gameEnd!);
          _rebuild();
          return;
        }
        state = state.copyWith(scrubPosition: newPos);
        _rebuild();
      },
    );
  }

  void _rebuild() {
    final cutoff = state.scrubPosition;
    final visible = _allEvents
        .where((e) => e.createdAt != null && !e.createdAt!.isAfter(cutoff))
        .toList();

    // Determine current phase
    String phase = 'waiting';
    for (final e in visible) {
      if (e.eventType == 'phase_change') {
        phase = e.payload['phase'] as String? ?? phase;
      }
    }

    state = state.copyWith(
      visibleEvents: visible,
      currentPhase: phase,
      questionEvents:
          visible.where((e) => e.eventType == 'question_asked').toList(),
      cardEvents: visible
          .where((e) =>
              e.eventType == 'card_drawn' || e.eventType == 'card_played')
          .toList(),
      locationEvents:
          visible.where((e) => e.eventType == 'location_update').toList(),
    );
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }
}

final replayControllerProvider = StateNotifierProvider.family<ReplayController,
    ReplayState, List<GameEvent>>(
  (ref, events) => ReplayController(events),
);
