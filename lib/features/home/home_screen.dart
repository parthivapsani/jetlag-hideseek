import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../app/theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(displayNameProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo/Title
              Text(
                'JET LAG',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                textAlign: TextAlign.center,
              ),
              Text(
                'HIDE & SEEK',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      letterSpacing: 8,
                      color: JetLagTheme.accentOrange,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Welcome message
              if (displayName != null)
                Text(
                  'Welcome back, $displayName',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              const Spacer(),

              // Main buttons
              _MainButton(
                label: 'Create Game',
                icon: Icons.add_circle_outline,
                color: JetLagTheme.hiderGreen,
                onPressed: () => context.push('/create-game'),
              ),
              const SizedBox(height: 16),
              _MainButton(
                label: 'Join Game',
                icon: Icons.group_add_outlined,
                color: JetLagTheme.seekerRed,
                onPressed: () => context.push('/join'),
              ),
              const SizedBox(height: 32),

              // Secondary buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => context.push('/auth'),
                      icon: const Icon(Icons.person_outline),
                      label: Text(displayName != null ? 'Account' : 'Sign In'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showRules(context),
                      icon: const Icon(Icons.help_outline),
                      label: const Text('Rules'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => context.push('/settings'),
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Settings'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showRules(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              _ruleSection(
                'The Basics',
                'One player is the Hider, the rest are Seekers. The Hider has a set amount of time to hide within a defined game area. Seekers must find the Hider before time runs out.',
              ),
              _ruleSection(
                'Hiding Phase',
                'The Hider travels to their hiding spot and establishes a 0.5 mile radius hiding zone. They cannot leave this zone once established.',
              ),
              _ruleSection(
                'Seeking Phase',
                'Seekers ask questions to narrow down the Hider\'s location. Questions cost coins and give the Hider cards.',
              ),
              _ruleSection(
                'Questions',
                '• Matching (30 coins): Which of these options matches?\n'
                    '• Measuring (30 coins): Distance/direction to landmarks\n'
                    '• Radar (25 coins): Within X distance of something?\n'
                    '• Thermometer (20 coins): Hot/cold relative to guess\n'
                    '• Tentacles (20 coins): Inside/outside drawn shapes\n'
                    '• Photo (15 coins): Send a photo',
              ),
              _ruleSection(
                'Cards',
                'The Hider draws cards when questions are asked. Cards can add bonus time, grant powers, or be curses that restrict movement.',
              ),
              _ruleSection(
                'Winning',
                'Seekers win by finding the Hider within the time limit. The Hider wins by remaining hidden until time expires.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(content),
        ],
      ),
    );
  }
}

class _MainButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _MainButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
