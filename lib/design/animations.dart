import 'package:flutter/material.dart';

/// Shared animation utilities for the Jet Lag design system.

// ============ Page Transitions ============

/// Horizontal slide transition for GoRouter pages.
CustomTransitionPage<void> slideTransitionPage({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: child,
        ),
      );
    },
  );
}

// Importing GoRouterState type
typedef GoRouterState = dynamic;

// ============ Stagger Animations ============

/// A widget that staggers its child's entrance animation.
class StaggeredItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration staggerDelay;
  final Duration duration;

  const StaggeredItem({
    super.key,
    required this.child,
    required this.index,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _slideAnimation = Tween(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    // Stagger start
    Future.delayed(widget.staggerDelay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}

// ============ Card Flip Animation ============

/// A widget that shows a flip-reveal animation.
class FlipReveal extends StatefulWidget {
  final Widget front;
  final Widget back;
  final Duration duration;
  final bool showFront;
  final VoidCallback? onFlipComplete;

  const FlipReveal({
    super.key,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 600),
    this.showFront = true,
    this.onFlipComplete,
  });

  @override
  State<FlipReveal> createState() => _FlipRevealState();
}

class _FlipRevealState extends State<FlipReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFlipComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(FlipReveal old) {
    super.didUpdateWidget(old);
    if (widget.showFront != old.showFront) {
      if (widget.showFront) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * 3.14159;
        final isFront = angle < 1.5708; // pi/2

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: isFront
              ? widget.front
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(3.14159),
                  child: widget.back,
                ),
        );
      },
    );
  }
}

// ============ Notification Slide-In ============

/// A notification that slides down from the top.
class SlideInNotification extends StatefulWidget {
  final Widget child;
  final bool visible;
  final Duration duration;

  const SlideInNotification({
    super.key,
    required this.child,
    this.visible = false,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<SlideInNotification> createState() => _SlideInNotificationState();
}

class _SlideInNotificationState extends State<SlideInNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _slideAnimation = Tween(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    if (widget.visible) _controller.forward();
  }

  @override
  void didUpdateWidget(SlideInNotification old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      _controller.forward();
    } else if (!widget.visible && old.visible) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: widget.child,
    );
  }
}

// ============ Glow Pulse ============

/// A pulsing glow effect for card reveals.
class GlowPulse extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final bool active;

  const GlowPulse({
    super.key,
    required this.child,
    required this.glowColor,
    this.active = false,
  });

  @override
  State<GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<GlowPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(GlowPulse old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && old.active) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: widget.active
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          widget.glowColor.withValues(alpha: 0.3 * _controller.value),
                      blurRadius: 20 + (10 * _controller.value),
                      spreadRadius: 2 * _controller.value,
                    ),
                  ],
                )
              : null,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
