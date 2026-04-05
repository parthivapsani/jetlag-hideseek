import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/widgets.dart';
import 'replay_controller.dart';
import 'replay_map.dart';

class ReplayScreen extends ConsumerWidget {
  final String sessionId;

  const ReplayScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(sessionEventsProvider(sessionId));

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Game Replay'),
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.replay, size: 48, color: context.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'No events recorded for this game',
                    style: TextStyle(color: context.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  JetlagButton(
                    label: 'Back',
                    variant: JetlagButtonVariant.secondary,
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                  ),
                ],
              ),
            );
          }
          return _ReplayBody(events: events);
        },
      ),
    );
  }
}

class _ReplayBody extends ConsumerWidget {
  final List<GameEvent> events;

  const _ReplayBody({required this.events});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(replayControllerProvider(events));
    final controller = ref.read(replayControllerProvider(events).notifier);

    return Column(
      children: [
        // Map area
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ReplayMapView(
              locationEvents: state.locationEvents,
              questionEvents: state.questionEvents,
              cardEvents: state.cardEvents,
              currentPhase: state.currentPhase,
            ),
          ),
        ),

        // Event log at current position
        Expanded(
          flex: 2,
          child: _EventLog(events: state.visibleEvents),
        ),

        // Scrubber controls
        _ScrubberBar(
          state: state,
          controller: controller,
        ),
      ],
    );
  }
}

class _EventLog extends StatelessWidget {
  final List<GameEvent> events;

  const _EventLog({required this.events});

  @override
  Widget build(BuildContext context) {
    final displayEvents = events.reversed.take(50).toList();

    if (displayEvents.isEmpty) {
      return Center(
        child: Text(
          'No events yet at this time',
          style: TextStyle(color: context.textTertiary, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      reverse: false,
      itemCount: displayEvents.length,
      itemBuilder: (context, index) {
        final event = displayEvents[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _eventColor(event.eventType, context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _eventLabel(event),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (event.createdAt != null)
                Text(
                  _formatTime(event.createdAt!),
                  style: TextStyle(
                    fontSize: 10,
                    color: context.textTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _eventColor(String type, BuildContext context) {
    switch (type) {
      case 'phase_change':
        return context.accent;
      case 'question_asked':
        return context.orange;
      case 'question_answered':
        return context.green;
      case 'card_drawn':
      case 'card_played':
        return context.purple;
      case 'curse_activated':
        return context.red;
      case 'round_started':
      case 'round_ended':
      case 'game_started':
      case 'game_ended':
        return context.accent;
      case 'timer_pause':
      case 'timer_resume':
        return context.orange;
      case 'player_joined':
      case 'player_left':
        return context.green;
      default:
        return context.textTertiary;
    }
  }

  String _eventLabel(GameEvent event) {
    switch (event.eventType) {
      case 'phase_change':
        return 'Phase \u2192 ${_capitalize(event.payload['phase'] as String? ?? '')}';
      case 'question_asked':
        return 'Question asked (${_capitalize(event.payload['category'] as String? ?? '')})';
      case 'question_answered':
        return 'Question answered';
      case 'card_drawn':
        return 'Card drawn: ${event.payload['cardId'] ?? ''}';
      case 'card_played':
        return 'Card played: ${event.payload['cardId'] ?? ''}';
      case 'curse_activated':
        return 'Curse: ${_capitalize(event.payload['curseType'] as String? ?? '')}';
      case 'round_started':
        return 'Round ${event.payload['roundNumber'] ?? ''} started';
      case 'round_ended':
        return 'Round ended (${event.payload['hideDurationSeconds'] ?? 0}s)';
      case 'game_ended':
        return 'Game over';
      case 'timer_pause':
        return 'Timer paused';
      case 'timer_resume':
        return 'Timer resumed';
      case 'player_joined':
        return 'Player joined team';
      default:
        return _capitalize(event.eventType.replaceAll('_', ' '));
    }
  }
}

class _ScrubberBar extends StatelessWidget {
  final ReplayState state;
  final ReplayController controller;

  const _ScrubberBar({
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(top: BorderSide(color: context.borderSubtle)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timeline scrubber with event markers
          Stack(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: context.accent,
                  inactiveTrackColor: context.surface3,
                  thumbColor: context.accent,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  trackHeight: 4,
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: state.progress,
                  onChanged: controller.scrubTo,
                  onChangeStart: (_) {
                    if (state.isPlaying) controller.pause();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Controls row
          Row(
            children: [
              // Elapsed time
              Text(
                _formatDuration(state.elapsed),
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),

              const Spacer(),

              // Play/pause
              GestureDetector(
                onTap: controller.togglePlayPause,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.accent,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    state.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Speed selector
              _SpeedButton(
                currentSpeed: state.playbackSpeed,
                onSpeedChange: controller.setSpeed,
              ),

              const Spacer(),

              // Total time
              Text(
                _formatDuration(state.totalDuration),
                style: TextStyle(
                  fontSize: 12,
                  color: context.textTertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedChange;

  const _SpeedButton({
    required this.currentSpeed,
    required this.onSpeedChange,
  });

  static const _speeds = [1.0, 2.0, 5.0, 10.0];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final idx = _speeds.indexOf(currentSpeed);
        final nextIdx = (idx + 1) % _speeds.length;
        onSpeedChange(_speeds[nextIdx]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: context.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderSubtle),
        ),
        child: Text(
          '${currentSpeed.toStringAsFixed(currentSpeed == currentSpeed.roundToDouble() ? 0 : 1)}x',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

// ============ Formatters ============

String _formatTime(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
