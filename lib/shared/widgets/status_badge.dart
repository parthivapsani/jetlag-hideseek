import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum BadgeVariant { filled, outlined, soft }

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final BadgeVariant variant;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.variant = BadgeVariant.soft,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final (bgColor, fgColor, borderColor) = switch (variant) {
      BadgeVariant.filled => (color, Colors.white, color),
      BadgeVariant.outlined => (Colors.transparent, color, color),
      BadgeVariant.soft => (color.withOpacity(0.15), color, Colors.transparent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: borderColor != Colors.transparent
            ? Border.all(color: borderColor, width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: fgColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Common badges
  factory StatusBadge.seeker() {
    return const StatusBadge(
      label: 'SEEKER',
      color: JetLagTheme.seekerRed,
      variant: BadgeVariant.filled,
    );
  }

  factory StatusBadge.hider() {
    return const StatusBadge(
      label: 'HIDER',
      color: JetLagTheme.hiderGreen,
      variant: BadgeVariant.filled,
    );
  }

  factory StatusBadge.spectator() {
    return const StatusBadge(
      label: 'SPECTATOR',
      color: JetLagTheme.spectatorGrey,
      variant: BadgeVariant.filled,
    );
  }

  factory StatusBadge.testMode() {
    return const StatusBadge(
      label: 'TEST',
      color: Colors.orange,
      icon: Icons.science,
      variant: BadgeVariant.soft,
    );
  }

  factory StatusBadge.live() {
    return const StatusBadge(
      label: 'LIVE',
      color: Colors.red,
      icon: Icons.circle,
      variant: BadgeVariant.filled,
      fontSize: 10,
    );
  }

  factory StatusBadge.paused() {
    return const StatusBadge(
      label: 'PAUSED',
      color: Colors.orange,
      icon: Icons.pause,
      variant: BadgeVariant.soft,
    );
  }

  factory StatusBadge.waiting() {
    return const StatusBadge(
      label: 'WAITING',
      color: Colors.blue,
      icon: Icons.hourglass_empty,
      variant: BadgeVariant.soft,
    );
  }

  factory StatusBadge.cooldown({required Duration remaining}) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return StatusBadge(
      label: '$minutes:${seconds.toString().padLeft(2, '0')}',
      color: Colors.orange,
      icon: Icons.timer,
      variant: BadgeVariant.outlined,
    );
  }

  factory StatusBadge.category(String category) {
    return StatusBadge(
      label: category.toUpperCase(),
      color: JetLagTheme.getCategoryColor(category),
      variant: BadgeVariant.filled,
    );
  }

  factory StatusBadge.cardType(String type) {
    return StatusBadge(
      label: _formatCardType(type),
      color: JetLagTheme.getCardTypeColor(type),
      variant: BadgeVariant.filled,
    );
  }

  static String _formatCardType(String type) {
    return switch (type.toLowerCase()) {
      'timebonus' || 'time_bonus' => 'TIME BONUS',
      'powerup' => 'POWERUP',
      'curse' => 'CURSE',
      'timetrap' || 'time_trap' => 'TIME TRAP',
      _ => type.toUpperCase(),
    };
  }
}

class ConnectionStatus extends StatelessWidget {
  final bool isConnected;

  const ConnectionStatus({super.key, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isConnected ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isConnected ? 'Connected' : 'Disconnected',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
