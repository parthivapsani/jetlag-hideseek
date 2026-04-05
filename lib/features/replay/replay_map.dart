import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';

/// Simplified replay map that shows event markers on a visual timeline map.
/// Uses a custom painter instead of Google Maps to avoid API costs during replay.
class ReplayMapView extends StatelessWidget {
  final List<GameEvent> locationEvents;
  final List<GameEvent> questionEvents;
  final List<GameEvent> cardEvents;
  final String currentPhase;

  const ReplayMapView({
    super.key,
    required this.locationEvents,
    required this.questionEvents,
    required this.cardEvents,
    required this.currentPhase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background grid
            CustomPaint(
              size: Size.infinite,
              painter: _GridPainter(
                gridColor: context.borderSubtle.withValues(alpha: 0.3),
              ),
            ),

            // Event activity visualization
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Phase indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _phaseColor(context).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _phaseColor(context).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _phaseColor(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentPhase.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _phaseColor(context),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Event counters
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _EventCounter(
                        icon: Icons.location_on,
                        count: locationEvents.length,
                        label: 'Locations',
                        color: context.accent,
                      ),
                      const SizedBox(width: 20),
                      _EventCounter(
                        icon: Icons.help_outline,
                        count: questionEvents.length,
                        label: 'Questions',
                        color: context.orange,
                      ),
                      const SizedBox(width: 20),
                      _EventCounter(
                        icon: Icons.style,
                        count: cardEvents.length,
                        label: 'Cards',
                        color: context.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _phaseColor(BuildContext context) {
    switch (currentPhase) {
      case 'hiding':
        return context.green;
      case 'seeking':
        return context.red;
      case 'endgame':
        return context.orange;
      default:
        return context.textTertiary;
    }
  }
}

class _EventCounter extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _EventCounter({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: context.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color gridColor;

  _GridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    const spacing = 30.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => gridColor != old.gridColor;
}
