import 'package:flutter/material.dart';

class TimerDisplay extends StatelessWidget {
  final Duration duration;
  final bool isCountingDown;
  final bool showHours;
  final TextStyle? style;
  final Color? warningColor;
  final Duration? warningThreshold;

  const TimerDisplay({
    super.key,
    required this.duration,
    this.isCountingDown = true,
    this.showHours = true,
    this.style,
    this.warningColor,
    this.warningThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final isWarning = warningThreshold != null &&
        isCountingDown &&
        duration <= warningThreshold!;

    final displayStyle = (style ?? Theme.of(context).textTheme.displaySmall)
        ?.copyWith(
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
      color: isWarning ? (warningColor ?? Colors.red) : null,
    );

    return Text(
      _formatDuration(duration),
      style: displayStyle,
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return showHours ? '0:00:00' : '0:00';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (showHours || hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class CountdownTimer extends StatefulWidget {
  final DateTime endTime;
  final Widget Function(Duration remaining) builder;
  final VoidCallback? onComplete;

  const CountdownTimer({
    super.key,
    required this.endTime,
    required this.builder,
    this.onComplete,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _startTimer();
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final remaining = widget.endTime.difference(now);
    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
    });
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      _updateRemaining();

      if (_remaining == Duration.zero) {
        widget.onComplete?.call();
        return false;
      }

      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_remaining);
  }
}
