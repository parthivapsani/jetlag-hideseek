import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_state_provider.freezed.dart';

/// Game phases
enum GamePhase {
  /// Lobby - players joining
  lobby,
  /// Hiding period - hider is traveling to hide
  hiding,
  /// Seeking - seekers are asking questions
  seeking,
  /// Endgame - seekers are in the hiding zone, hider cannot move
  endgame,
  /// Game over
  finished,
}

/// Seeker-side game state for question drafting
@freezed
class SeekerGameState with _$SeekerGameState {
  const factory SeekerGameState({
    required GamePhase phase,

    /// Current seeker position (lat, lng)
    @Default(null) (double, double)? seekerPosition,

    /// Known hiding zone center (revealed in endgame or estimated)
    @Default(null) (double, double)? hidingZoneCenter,

    /// Hiding zone radius in meters (default 0.5 miles = 804.672m)
    @Default(804.672) double hidingZoneRadius,

    /// Secondary boundary for "squish" - how far hider could move
    /// When asking "within 0.25 miles", actual boundary is 0.25 + squishRadius
    @Default(804.672) double squishRadius,

    /// Whether to show the squish boundary (false in endgame)
    @Default(true) bool showSquishBoundary,

    /// Excluded areas from answers (polygon regions ruled out)
    @Default([]) List<List<(double, double)>> excludedAreas,

    /// Included areas (polygon regions where hider must be)
    @Default([]) List<List<(double, double)>> includedAreas,
  }) = _SeekerGameState;
}

/// Provider for seeker game state
class SeekerGameStateNotifier extends StateNotifier<SeekerGameState> {
  SeekerGameStateNotifier() : super(const SeekerGameState(phase: GamePhase.lobby));

  void setPhase(GamePhase phase) {
    state = state.copyWith(
      phase: phase,
      // In endgame, don't show squish boundary
      showSquishBoundary: phase != GamePhase.endgame && phase != GamePhase.finished,
    );
  }

  void startEndgame() {
    state = state.copyWith(
      phase: GamePhase.endgame,
      showSquishBoundary: false,
    );
  }

  void updateSeekerPosition(double lat, double lng) {
    state = state.copyWith(seekerPosition: (lat, lng));
  }

  void updateHidingZone(double lat, double lng, {double? radius}) {
    state = state.copyWith(
      hidingZoneCenter: (lat, lng),
      hidingZoneRadius: radius ?? state.hidingZoneRadius,
    );
  }

  void setSquishRadius(double radius) {
    state = state.copyWith(squishRadius: radius);
  }

  void toggleSquishBoundary(bool show) {
    state = state.copyWith(showSquishBoundary: show);
  }

  void addExcludedArea(List<(double, double)> polygon) {
    state = state.copyWith(
      excludedAreas: [...state.excludedAreas, polygon],
    );
  }

  void addIncludedArea(List<(double, double)> polygon) {
    state = state.copyWith(
      includedAreas: [...state.includedAreas, polygon],
    );
  }

  void clearAreas() {
    state = state.copyWith(excludedAreas: [], includedAreas: []);
  }
}

final seekerGameStateProvider =
    StateNotifierProvider<SeekerGameStateNotifier, SeekerGameState>((ref) {
  return SeekerGameStateNotifier();
});

/// Quick access providers
final gamePhaseProvider = Provider<GamePhase>((ref) {
  return ref.watch(seekerGameStateProvider).phase;
});

final isEndgameProvider = Provider<bool>((ref) {
  final phase = ref.watch(gamePhaseProvider);
  return phase == GamePhase.endgame;
});

final showSquishBoundaryProvider = Provider<bool>((ref) {
  return ref.watch(seekerGameStateProvider).showSquishBoundary;
});

final squishRadiusProvider = Provider<double>((ref) {
  return ref.watch(seekerGameStateProvider).squishRadius;
});
