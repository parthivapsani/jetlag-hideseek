import 'package:flutter/material.dart';
import '../colors.dart';
import '../theme.dart';

/// Card with top-edge glow line and surface background.
class JetlagCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const JetlagCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderColor ?? context.borderSubtle;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(JetlagRadii.lg),
          border: Border.all(color: effectiveBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(JetlagRadii.lg),
          child: Stack(
            children: [
              Padding(padding: padding, child: child),
              // Top-edge glow line
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        context.border.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                      stops: const [0.1, 0.5, 0.9],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
