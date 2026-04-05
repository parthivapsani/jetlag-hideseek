import 'package:flutter/material.dart';
import '../colors.dart';

enum JetlagBadgeColor { green, red, orange, blue, purple }

class JetlagBadge extends StatelessWidget {
  final String label;
  final JetlagBadgeColor color;
  final bool showPulse;

  const JetlagBadge({
    super.key,
    required this.label,
    required this.color,
    this.showPulse = false,
  });

  (Color, Color) _colors() {
    switch (color) {
      case JetlagBadgeColor.green:
        return (JetlagColors.greenGlow, JetlagColors.green);
      case JetlagBadgeColor.red:
        return (JetlagColors.redGlow, JetlagColors.red);
      case JetlagBadgeColor.orange:
        return (JetlagColors.orangeGlow, JetlagColors.orange);
      case JetlagBadgeColor.blue:
        return (JetlagColors.accentGlow, JetlagColors.accent);
      case JetlagBadgeColor.purple:
        return (JetlagColors.purpleGlow, JetlagColors.purple);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: bg, blurRadius: 8, spreadRadius: -2)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPulse) ...[
            _PulseDot(color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = (1 + Curves.easeInOut.transform((_ctrl.value * 2 - 1).abs())) / 2;
        return Opacity(
          opacity: 0.4 + 0.6 * t,
          child: Transform.scale(
            scale: 0.8 + 0.2 * t,
            child: Container(
              width: 6, height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ),
        );
      },
    );
  }
}
