import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/jetlag_card.dart';
import '../../design/widgets/jetlag_button.dart';

// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final displayName = ref.watch(displayNameProvider);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        foregroundColor: context.textPrimary,
        title: Text(
          'Settings',
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimary),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Profile section
          _SectionLabel('Profile'),
          const SizedBox(height: 8),
          JetlagCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: context.accent.withValues(alpha: 0.2),
                  child: Text(
                    (displayName ?? 'P')[0].toUpperCase(),
                    style: TextStyle(
                      color: context.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName ?? 'Player',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        'Anonymous player',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Appearance section
          _SectionLabel('Appearance'),
          const SizedBox(height: 8),
          JetlagCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.brightness_6, size: 18, color: context.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      'Theme',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Pill selector
                Container(
                  decoration: BoxDecoration(
                    color: context.surface2,
                    borderRadius: BorderRadius.circular(JetlagRadii.sm),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      _ThemePill(
                        label: 'System',
                        isActive: themeMode == ThemeMode.system,
                        onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                      ),
                      _ThemePill(
                        label: 'Light',
                        isActive: themeMode == ThemeMode.light,
                        onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                      ),
                      _ThemePill(
                        label: 'Dark',
                        isActive: themeMode == ThemeMode.dark,
                        onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Game Defaults section
          _SectionLabel('Game Defaults'),
          const SizedBox(height: 8),
          JetlagCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.timer,
                  label: 'Default Hiding Period',
                  value: '1 hour',
                  onTap: () => _showComingSoon(context),
                ),
                Divider(height: 1, color: context.borderSubtle),
                _SettingsRow(
                  icon: Icons.circle_outlined,
                  label: 'Default Zone Radius',
                  value: '0.5 miles',
                  onTap: () => _showComingSoon(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Map section
          _SectionLabel('Map'),
          const SizedBox(height: 8),
          JetlagCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ToggleRow(
                  icon: Icons.traffic,
                  label: 'Show Traffic',
                  subtitle: 'Display real-time traffic on map',
                  value: false,
                  onChanged: (value) {},
                ),
                Divider(height: 1, color: context.borderSubtle),
                _ToggleRow(
                  icon: Icons.directions_transit,
                  label: 'Show Transit',
                  subtitle: 'Display transit lines and stations',
                  value: true,
                  onChanged: (value) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About section
          _SectionLabel('About'),
          const SizedBox(height: 8),
          JetlagCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.info_outline,
                  label: 'About Jet Lag Hide & Seek',
                  onTap: () => _showAbout(context),
                ),
                Divider(height: 1, color: context.borderSubtle),
                _SettingsRow(
                  icon: Icons.help_outline,
                  label: 'How to Play',
                  onTap: () => _showHowToPlay(context),
                ),
                Divider(height: 1, color: context.borderSubtle),
                _SettingsRow(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () {},
                ),
                Divider(height: 1, color: context.borderSubtle),
                _SettingsRow(
                  icon: Icons.code,
                  label: 'Open Source Licenses',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Jet Lag Hide & Seek',
                    applicationVersion: '1.0.0',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Version
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(fontSize: 12, color: context.textTertiary),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon!')),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surface,
        title: Text('About', style: TextStyle(color: ctx.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jet Lag Hide & Seek Companion',
              style: TextStyle(fontWeight: FontWeight.bold, color: ctx.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'A companion app for playing Jet Lag: The Game Hide and Seek format, '
              'inspired by seasons 12 and 16 of the show.',
              style: TextStyle(color: ctx.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'This is a fan-made project and is not affiliated with '
              'Wendover Productions or Jet Lag: The Game.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: ctx.textTertiary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: ctx.accent)),
          ),
        ],
      ),
    );
  }

  void _showHowToPlay(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: context.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'How to Play',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            _HowToPlayStep(number: 1, title: 'Create or Join a Game',
              description: 'One player creates a game by drawing the game area on the map. Other players join using the 6-character room code.'),
            _HowToPlayStep(number: 2, title: 'Choose Roles',
              description: 'One player becomes the Hider, the rest are Seekers. Spectators can watch without participating.'),
            _HowToPlayStep(number: 3, title: 'Hiding Period',
              description: 'The Hider has a set amount of time to travel anywhere within the game area. Once they stop, they establish a hiding zone.'),
            _HowToPlayStep(number: 4, title: 'Seeking Phase',
              description: 'Seekers ask questions from 6 categories (Matching, Measuring, Radar, Thermometer, Tentacles, Photo) to narrow down the Hider\'s location. Each question lets the Hider draw cards.'),
            _HowToPlayStep(number: 5, title: 'Cards & Curses',
              description: 'Cards give the Hider bonus time, powerups, or curses that restrict their movement. Strategic card play is key!'),
            _HowToPlayStep(number: 6, title: 'Endgame',
              description: 'Seekers must physically find the Hider within the hiding zone before time runs out. If the Hider survives, they win!'),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.accent,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ThemePill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? context.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(JetlagRadii.sm - 2),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(JetlagRadii.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textPrimary,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: TextStyle(fontSize: 13, color: context.textTertiary),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, color: context.textPrimary)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: context.textTertiary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: context.accent,
          ),
        ],
      ),
    );
  }
}

class _HowToPlayStep extends StatelessWidget {
  final int number;
  final String title;
  final String description;

  const _HowToPlayStep({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: context.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
