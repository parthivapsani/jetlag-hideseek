import 'package:flutter/material.dart';
import '../theme.dart';

class JetlagSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const JetlagSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 10,
  });

  @override
  State<JetlagSkeleton> createState() => _JetlagSkeletonState();
}

class _JetlagSkeletonState extends State<JetlagSkeleton> with SingleTickerProviderStateMixin {
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
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-1.0 + 2.0 * _ctrl.value + 1.0, 0),
              colors: [
                context.surface2,
                context.surface3,
                context.surface2,
              ],
            ),
          ),
        );
      },
    );
  }
}
