import 'package:flutter/material.dart';
import '../colors.dart';
import '../theme.dart';

enum JetlagButtonVariant { primary, secondary, danger }

class JetlagButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final JetlagButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  const JetlagButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = JetlagButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<JetlagButton> createState() => _JetlagButtonState();
}

class _JetlagButtonState extends State<JetlagButton> {
  bool _hovering = false;

  Color _bgColor(BuildContext context) {
    switch (widget.variant) {
      case JetlagButtonVariant.primary:
        return context.accent;
      case JetlagButtonVariant.secondary:
        return context.surface2;
      case JetlagButtonVariant.danger:
        return context.red;
    }
  }

  Color _textColor(BuildContext context) {
    switch (widget.variant) {
      case JetlagButtonVariant.primary:
      case JetlagButtonVariant.danger:
        return Colors.white;
      case JetlagButtonVariant.secondary:
        return context.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          // ignore: deprecated_member_use
          transform: Matrix4.identity()..translate(0.0, _hovering && !disabled ? -1.0 : 0.0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: _bgColor(context).withValues(alpha: disabled ? 0.4 : 1.0),
            borderRadius: BorderRadius.circular(JetlagRadii.sm),
            border: widget.variant == JetlagButtonVariant.secondary
                ? Border.all(color: context.border)
                : null,
            boxShadow: _hovering && !disabled
                ? [const BoxShadow(color: JetlagColors.accentGlow, blurRadius: 16, offset: Offset(0, 4))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _textColor(context)),
                  ),
                )
              else if (widget.icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(widget.icon, size: 16, color: _textColor(context)),
                ),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: _textColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
