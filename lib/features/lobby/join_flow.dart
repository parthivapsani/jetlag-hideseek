import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/supabase_init.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/jetlag_button.dart';
import '../../design/widgets/jetlag_card.dart';
import '../../design/widgets/jetlag_input.dart';

class JoinFlow extends ConsumerStatefulWidget {
  final String sessionCode;
  final String sessionId;
  final List<Participant> existingParticipants;
  final VoidCallback onJoined;

  const JoinFlow({
    super.key,
    required this.sessionCode,
    required this.sessionId,
    required this.existingParticipants,
    required this.onJoined,
  });

  @override
  ConsumerState<JoinFlow> createState() => _JoinFlowState();
}

class _JoinFlowState extends ConsumerState<JoinFlow> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final displayName = ref.read(displayNameProvider);
    if (displayName != null) {
      _nameController.text = displayName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'Join Game',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Claim existing identity
            if (widget.existingParticipants.isNotEmpty) ...[
              Text(
                'Already in this game? Tap your name:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.existingParticipants.map((p) {
                  return _ParticipantChip(
                    name: p.displayName,
                    isHost: p.isHost,
                    onTap: () => _claimIdentity(p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: Divider(color: context.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: context.border)),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Join as new player
            Text(
              'Join as someone new:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            JetlagInput(
              label: 'Your Name',
              hint: 'Enter your display name',
              controller: _nameController,
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: context.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

            JetlagButton(
              label: 'Join',
              icon: Icons.login,
              variant: JetlagButtonVariant.primary,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _joinAsNew,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _claimIdentity(Participant participant) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Store participant ID in localStorage for this game
      await GameParticipantStorage.setParticipantId(
        widget.sessionCode,
        participant.id,
      );

      // Set current participant in provider
      ref.read(currentParticipantIdProvider.notifier).state = participant.id;

      // Update display name
      await ref
          .read(displayNameProvider.notifier)
          .setDisplayName(participant.displayName);

      widget.onJoined();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error claiming identity: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _joinAsNew() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save display name
      await ref.read(displayNameProvider.notifier).setDisplayName(name);

      // Set session ID for game actions
      ref.read(currentSessionIdProvider.notifier).state = widget.sessionId;

      // Check if creator (host)
      final session = await ref.read(supabaseServiceProvider)!.getSession(widget.sessionId);
      final deviceToken = await ref.read(deviceTokenProvider.future);
      final isHost = session?.createdBy == deviceToken;

      // Create participant
      final participant =
          await ref.read(gameActionsProvider)!.joinAsParticipant(
                displayName: name,
                role: ParticipantRole.seeker,
                isHost: isHost,
              );

      // Auto-assign to the team with fewer members
      final teams = ref.read(teamsProvider).valueOrNull ?? [];
      final participants = ref.read(participantsProvider).valueOrNull ?? [];
      if (teams.length >= 2) {
        final counts = <String, int>{};
        for (final t in teams) {
          counts[t.id] =
              participants.where((p) => p.teamId == t.id).length;
        }
        final sorted = teams.toList()
          ..sort(
              (a, b) => (counts[a.id] ?? 0).compareTo(counts[b.id] ?? 0));
        await ref
            .read(teamActionsProvider)
            ?.switchTeam(participant.id, sorted.first.id);
      }

      // Store participant ID in localStorage
      await GameParticipantStorage.setParticipantId(
        widget.sessionCode,
        participant.id,
      );

      widget.onJoined();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error joining game: $e';
        _isLoading = false;
      });
    }
  }
}

class _ParticipantChip extends StatelessWidget {
  final String name;
  final bool isHost;
  final VoidCallback onTap;

  const _ParticipantChip({
    required this.name,
    required this.onTap,
    this.isHost = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(JetlagRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.surface2,
            borderRadius: BorderRadius.circular(JetlagRadii.sm),
            border: Border.all(color: context.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: context.accent.withValues(alpha: 0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
              if (isHost) ...[
                const SizedBox(width: 4),
                Icon(Icons.star_rounded, size: 14, color: context.orange),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
