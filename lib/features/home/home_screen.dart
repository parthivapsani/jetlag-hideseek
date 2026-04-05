import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/jetlag_button.dart';
import '../../design/widgets/jetlag_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _joinController = TextEditingController();
  String? _joinError;

  @override
  void dispose() {
    _joinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = ref.watch(displayNameProvider);

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Gradient heading
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [context.accent, JetlagColors.accent2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  'JET LAG',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: Colors.white, // masked by shader
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [context.accent, JetlagColors.purple],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(bounds),
                child: Text(
                  'HIDE & SEEK',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 10,
                    color: Colors.white,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),

              // Welcome message
              if (displayName != null)
                Text(
                  'Welcome back, $displayName',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

              const Spacer(flex: 2),

              // Join Game field
              JetlagCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Join Game',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paste a game URL or code',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _joinController,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'URL or game code',
                              hintStyle: TextStyle(color: context.textTertiary),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _handleJoin(),
                            onChanged: (_) {
                              if (_joinError != null) {
                                setState(() => _joinError = null);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        JetlagButton(
                          label: 'Go',
                          variant: JetlagButtonVariant.primary,
                          onPressed: _handleJoin,
                        ),
                      ],
                    ),
                    if (_joinError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _joinError!,
                        style: TextStyle(color: context.red, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: JetlagButton(
                    label: 'How to Play',
                    icon: Icons.help_outline,
                    variant: JetlagButtonVariant.secondary,
                    onPressed: () => _showRules(context),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Bottom icon row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IconBtn(
                    icon: Icons.lightbulb_outline,
                    label: 'Ideas',
                    onTap: () => context.push('/ideas'),
                    color: context.textSecondary,
                  ),
                  const SizedBox(width: 32),
                  _IconBtn(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => context.push('/settings'),
                    color: context.textSecondary,
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

  void _handleJoin() {
    final input = _joinController.text.trim();
    if (input.isEmpty) {
      setState(() => _joinError = 'Please enter a game URL or code');
      return;
    }

    // Extract code from URL or use raw input
    String code = input;

    // Handle full URLs: https://jetlag.ratz.fyi/g/XXXX or .../join/XXXX
    final uriMatch = RegExp(r'(?:/g/|/join/)([A-Za-z0-9_-]+)').firstMatch(input);
    if (uriMatch != null) {
      code = uriMatch.group(1)!;
    } else {
      // Strip any leading/trailing slashes or whitespace
      code = code.replaceAll(RegExp(r'^[/\s]+|[/\s]+$'), '');
    }

    if (code.isEmpty) {
      setState(() => _joinError = 'Could not parse game code');
      return;
    }

    context.go('/g/$code');
  }

  void _showRules(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
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
              const SizedBox(height: 16),
              _ruleSection(context, 'The Basics',
                'One player is the Hider, the rest are Seekers. The Hider has a set amount of time to hide within a defined game area. Seekers must find the Hider before time runs out.'),
              _ruleSection(context, 'Hiding Phase',
                'The Hider travels to their hiding spot and establishes a 0.5 mile radius hiding zone. They cannot leave this zone once established.'),
              _ruleSection(context, 'Seeking Phase',
                'Seekers ask questions to narrow down the Hider\'s location. Each question lets the Hider draw cards.'),
              _ruleSection(context, 'Questions',
                '- Matching (Draw 3, Keep 1): Is your X the same as ours?\n'
                '- Measuring (Draw 3, Keep 1): Are you closer to X than us?\n'
                '- Radar (Draw 2, Keep 1): Within X distance of us?\n'
                '- Thermometer (Draw 2, Keep 1): Warmer or colder?\n'
                '- Tentacles (Draw 4, Keep 2): Which X near us is closest to you?\n'
                '- Photo (Draw 1): Send a picture'),
              _ruleSection(context, 'Cards',
                'The Hider draws cards when questions are asked. Cards can add bonus time, grant powers, or be curses that restrict movement.'),
              _ruleSection(context, 'Winning',
                'Seekers win by finding the Hider within the time limit. The Hider wins by remaining hidden until time expires.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _IconBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
