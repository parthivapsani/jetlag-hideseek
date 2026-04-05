import 'package:flutter/material.dart';
import '../theme.dart';

class JetlagTimer extends StatelessWidget {
  final Duration duration;
  final Duration? warningThreshold;
  final double fontSize;
  final String? suffix;

  const JetlagTimer({
    super.key,
    required this.duration,
    this.warningThreshold,
    this.fontSize = 22,
    this.suffix,
  });

  String _format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isWarning = warningThreshold != null && duration <= warningThreshold!;
    final color = isWarning ? context.red : context.textPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          _format(duration),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: color,
          ),
        ),
        if (suffix != null) ...[
          const SizedBox(width: 6),
          Text(suffix!, style: TextStyle(fontSize: 11, color: context.textTertiary)),
        ],
      ],
    );
  }
}
