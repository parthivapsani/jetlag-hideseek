import 'package:flutter/material.dart';
import '../colors.dart';

enum GameRole { hider, seeker, spectator }

class JetlagStatusBar extends StatelessWidget {
  final GameRole role;
  final String label;
  final Widget? trailing;

  const JetlagStatusBar({
    super.key,
    required this.role,
    required this.label,
    this.trailing,
  });

  Color _bgColor() {
    switch (role) {
      case GameRole.hider:
        return JetlagColors.green;
      case GameRole.seeker:
        return JetlagColors.red;
      case GameRole.spectator:
        return JetlagColors.darkSurface3;
    }
  }

  Color _fgColor() {
    switch (role) {
      case GameRole.hider:
      case GameRole.seeker:
        return Colors.black;
      case GameRole.spectator:
        return JetlagColors.darkText2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: _bgColor(),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _fgColor(),
                letterSpacing: 0.8,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
