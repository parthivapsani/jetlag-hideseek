import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../app/theme.dart';

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
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          // Profile section
          _SectionHeader(title: 'Profile'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: JetLagTheme.primaryBlue,
              child: Text(
                (displayName ?? 'P')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(displayName ?? 'Player'),
            subtitle: Text(user?.email ?? 'Playing anonymously'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/auth'),
          ),

          const Divider(),

          // Appearance section
          _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme'),
            subtitle: Text(_getThemeModeName(themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemePicker(context, ref),
          ),

          const Divider(),

          // Game settings
          _SectionHeader(title: 'Game Defaults'),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('Default Hiding Period'),
            subtitle: const Text('1 hour'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDurationPicker(context),
          ),
          ListTile(
            leading: const Icon(Icons.circle_outlined),
            title: const Text('Default Zone Radius'),
            subtitle: const Text('0.5 miles'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRadiusPicker(context),
          ),

          const Divider(),

          // Map settings
          _SectionHeader(title: 'Map'),
          SwitchListTile(
            secondary: const Icon(Icons.traffic),
            title: const Text('Show Traffic'),
            subtitle: const Text('Display real-time traffic on map'),
            value: false, // TODO: Implement
            onChanged: (value) {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.directions_transit),
            title: const Text('Show Transit'),
            subtitle: const Text('Display transit lines and stations'),
            value: true, // TODO: Implement
            onChanged: (value) {},
          ),

          const Divider(),

          // About section
          _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Jet Lag Hide & Seek'),
            onTap: () => _showAbout(context),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('How to Play'),
            onTap: () => _showHowToPlay(context),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () {
              // TODO: Open privacy policy
            },
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open Source Licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Jet Lag Hide & Seek',
              applicationVersion: '1.0.0',
            ),
          ),

          const SizedBox(height: 24),

          // Version info
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Made with Flutter',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            return RadioListTile<ThemeMode>(
              title: Text(_getThemeModeName(mode)),
              value: mode,
              groupValue: ref.read(themeModeProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(value);
                }
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDurationPicker(BuildContext context) {
    // TODO: Implement duration picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon!')),
    );
  }

  void _showRadiusPicker(BuildContext context) {
    // TODO: Implement radius picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon!')),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jet Lag Hide & Seek Companion',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'A companion app for playing Jet Lag: The Game Hide and Seek format, '
              'inspired by seasons 12 and 16 of the show.',
            ),
            SizedBox(height: 16),
            Text(
              'This is a fan-made project and is not affiliated with '
              'Wendover Productions or Jet Lag: The Game.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHowToPlay(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'How to Play',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            _HowToPlayStep(
              number: 1,
              title: 'Create or Join a Game',
              description:
                  'One player creates a game by drawing the game area on the map. '
                  'Other players join using the 6-character room code.',
            ),
            _HowToPlayStep(
              number: 2,
              title: 'Choose Roles',
              description:
                  'One player becomes the Hider, the rest are Seekers. '
                  'Spectators can watch without participating.',
            ),
            _HowToPlayStep(
              number: 3,
              title: 'Hiding Period',
              description:
                  'The Hider has a set amount of time to travel anywhere within '
                  'the game area. Once they stop, they establish a hiding zone.',
            ),
            _HowToPlayStep(
              number: 4,
              title: 'Seeking Phase',
              description:
                  'Seekers ask questions from 6 categories (Matching, Measuring, '
                  'Radar, Thermometer, Tentacles, Photo) to narrow down '
                  'the Hider\'s location. Each question lets the Hider draw cards.',
            ),
            _HowToPlayStep(
              number: 5,
              title: 'Cards & Curses',
              description:
                  'Cards give the Hider bonus time, powerups, or curses that '
                  'restrict their movement. Strategic card play is key!',
            ),
            _HowToPlayStep(
              number: 6,
              title: 'Endgame',
              description:
                  'Seekers must physically find the Hider within the hiding zone '
                  'before time runs out. If the Hider survives, they win!',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1,
        ),
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
