import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/supabase_init.dart';
import '../../design/widgets/widgets.dart';
import '../../design/theme.dart';
import '../../design/colors.dart';
import 'join_flow.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  /// The nanoid code from /g/:code route
  final String? sessionCode;
  /// Legacy: the session UUID from /lobby/:sessionId route
  final String? sessionId;

  const LobbyScreen({super.key, this.sessionCode, this.sessionId});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _hasJoined = false;
  bool _isLoading = true;
  String? _resolvedSessionId;
  String? _resolvedCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  Future<void> _resolveSession() async {
    try {
      final service = ref.read(supabaseServiceProvider);
      if (service == null) {
        setState(() {
          _error = 'Not connected to server';
          _isLoading = false;
        });
        return;
      }

      GameSession? session;

      if (widget.sessionCode != null) {
        // Try by room code (nanoid)
        session = await service.getSessionByRoomCode(widget.sessionCode!);
        _resolvedCode = widget.sessionCode;
      } else if (widget.sessionId != null) {
        // Legacy: by session ID
        session = await service.getSession(widget.sessionId!);
        _resolvedCode = session?.roomCode;
      }

      if (session == null) {
        setState(() {
          _error = 'Game not found';
          _isLoading = false;
        });
        return;
      }

      _resolvedSessionId = session.id;
      _resolvedCode ??= session.roomCode;

      // Set up providers
      ref.read(currentSessionIdProvider.notifier).state = session.id;

      // Check localStorage for existing participant ID
      final storedParticipantId =
          await GameParticipantStorage.getParticipantId(_resolvedCode!);

      if (storedParticipantId != null) {
        // Verify this participant still exists in the session
        final participants = await service.getParticipants(session.id);
        final found = participants.where((p) => p.id == storedParticipantId).firstOrNull;
        if (found != null) {
          ref.read(currentParticipantIdProvider.notifier).state = storedParticipantId;
          setState(() {
            _hasJoined = true;
            _isLoading = false;
          });
          return;
        } else {
          // Stale participant ID, clear it
          await GameParticipantStorage.removeParticipantId(_resolvedCode!);
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading game: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              JetlagButton(
                label: 'Go Home',
                variant: JetlagButtonVariant.secondary,
                onPressed: () => context.go('/'),
              ),
            ],
          ),
        ),
      );
    }

    final sessionAsync = ref.watch(currentSessionProvider);
    final participantsAsync = ref.watch(participantsProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final currentParticipant = ref.watch(currentParticipantProvider);
    final balanced = ref.watch(teamsBalancedProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
      data: (session) {
        if (session == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Game not found',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  JetlagButton(
                    label: 'Go Home',
                    variant: JetlagButtonVariant.secondary,
                    onPressed: () => context.go('/'),
                  ),
                ],
              ),
            ),
          );
        }

        // Redirect if game has started
        if (session.status != SessionStatus.waiting &&
            currentParticipant != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToGame(currentParticipant.role);
          });
        }

        // Show join flow if not joined yet
        if (!_hasJoined) {
          final participants = participantsAsync.valueOrNull ?? [];
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.go('/'),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: JoinFlow(
                      sessionCode: _resolvedCode!,
                      sessionId: _resolvedSessionId!,
                      existingParticipants: participants,
                      onJoined: () => setState(() => _hasJoined = true),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Back button row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _leaveLobby,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // Share link header
                _ShareLinkHeader(
                  code: _resolvedCode!,
                  onCopy: () => _copyGameLink(),
                ),

                const SizedBox(height: 16),

                // Main content
                Expanded(
                  child: _buildTeamLayout(
                      teamsAsync, participantsAsync, currentParticipant),
                ),

                // Unassigned players
                _buildUnassignedPlayers(
                    participantsAsync, teamsAsync, currentParticipant),

                // Start button (host only)
                if (currentParticipant?.isHost == true)
                  _buildStartButton(balanced),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeamLayout(
    AsyncValue<List<Team>> teamsAsync,
    AsyncValue<List<Participant>> participantsAsync,
    Participant? currentParticipant,
  ) {
    return teamsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (teams) {
        return participantsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (participants) {
            if (teams.length < 2) {
              return const Center(child: CircularProgressIndicator());
            }

            final teamAlpha = teams.firstWhere((t) => t.displayOrder == 0,
                orElse: () => teams.first);
            final teamBeta = teams.firstWhere((t) => t.displayOrder == 1,
                orElse: () => teams.last);

            final alphaMembers =
                participants.where((p) => p.teamId == teamAlpha.id).toList();
            final betaMembers =
                participants.where((p) => p.teamId == teamBeta.id).toList();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _TeamColumn(
                            team: teamAlpha,
                            members: alphaMembers,
                            currentParticipantId: currentParticipant?.id,
                            onTapMember: (p) =>
                                _onTapParticipant(p, teamBeta.id),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TeamColumn(
                            team: teamBeta,
                            members: betaMembers,
                            currentParticipantId: currentParticipant?.id,
                            onTapMember: (p) =>
                                _onTapParticipant(p, teamAlpha.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap a name to switch teams',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUnassignedPlayers(
    AsyncValue<List<Participant>> participantsAsync,
    AsyncValue<List<Team>> teamsAsync,
    Participant? currentParticipant,
  ) {
    final participants = participantsAsync.valueOrNull ?? [];
    final teams = teamsAsync.valueOrNull ?? [];
    final teamIds = teams.map((t) => t.id).toSet();
    final unassigned =
        participants.where((p) => p.teamId == null || !teamIds.contains(p.teamId)).toList();

    if (unassigned.isEmpty) return const SizedBox.shrink();

    final firstTeamId = teams.isNotEmpty ? teams.first.id : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: JetlagCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unassigned (${unassigned.length})',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: unassigned.map((p) {
                final isMe = p.id == currentParticipant?.id;
                return GestureDetector(
                  onTap: firstTeamId != null
                      ? () => _switchTeam(p.id, firstTeamId)
                      : null,
                  child: Chip(
                    label: Text(
                      p.displayName + (isMe ? ' (you)' : ''),
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe ? context.accent : context.textPrimary,
                      ),
                    ),
                    backgroundColor: context.surface2,
                    side: BorderSide(color: context.borderSubtle),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(bool balanced) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!balanced)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Teams must be balanced to start',
                style: TextStyle(
                  color: context.red,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: JetlagButton(
              label: 'Start Round 1',
              onPressed: balanced ? _startGame : null,
            ),
          ),
        ],
      ),
    );
  }

  void _onTapParticipant(Participant participant, String otherTeamId) {
    _switchTeam(participant.id, otherTeamId);
  }

  Future<void> _switchTeam(String participantId, String teamId) async {
    try {
      await ref.read(teamActionsProvider)?.switchTeam(participantId, teamId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error switching team: $e')),
        );
      }
    }
  }

  Future<void> _startGame() async {
    try {
      await ref.read(gameActionsProvider)!.startHidingPeriod();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting game: $e')),
        );
      }
    }
  }

  void _navigateToGame(ParticipantRole role) {
    final sessionId = _resolvedSessionId!;
    switch (role) {
      case ParticipantRole.hider:
        context.go('/game/$sessionId/hider');
        break;
      case ParticipantRole.seeker:
        context.go('/game/$sessionId/seeker');
        break;
      case ParticipantRole.spectator:
        context.go('/game/$sessionId/spectator');
        break;
    }
  }

  Future<void> _leaveLobby() async {
    if (_resolvedCode != null) {
      await GameParticipantStorage.removeParticipantId(_resolvedCode!);
    }
    await ref.read(gameActionsProvider)?.leaveSession();
    if (mounted) {
      context.go('/');
    }
  }

  void _copyGameLink() {
    final url = 'https://jetlag.ratz.fyi/g/$_resolvedCode';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Game link copied!')),
    );
  }
}

// ============ Share Link Header ============

class _ShareLinkHeader extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;

  const _ShareLinkHeader({required this.code, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: JetlagCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                children: [
                  Text('SHARE GAME LINK',
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    'jetlag.ratz.fyi/g/${code.length > 12 ? '${code.substring(0, 12)}...' : code}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.accent,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.copy_rounded, color: context.textSecondary),
              onPressed: onCopy,
              tooltip: 'Copy game link',
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Team Column ============

class _TeamColumn extends StatelessWidget {
  final Team team;
  final List<Participant> members;
  final String? currentParticipantId;
  final void Function(Participant) onTapMember;

  const _TeamColumn({
    required this.team,
    required this.members,
    required this.currentParticipantId,
    required this.onTapMember,
  });

  Color _teamColor(BuildContext context) {
    switch (team.color) {
      case 'green':
        return context.green;
      case 'red':
        return context.red;
      default:
        return context.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _teamColor(context);

    return JetlagCard(
      borderColor: color.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Team header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  team.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${members.length} player${members.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 16),

          // Member list
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No players yet',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ...members.map((p) {
              final isMe = p.id == currentParticipantId;
              return _MemberTile(
                name: p.displayName,
                isCurrentUser: isMe,
                isHost: p.isHost,
                accentColor: color,
                onTap: () => onTapMember(p),
              );
            }),
        ],
      ),
    );
  }
}

// ============ Member Tile ============

class _MemberTile extends StatelessWidget {
  final String name;
  final bool isCurrentUser;
  final bool isHost;
  final Color accentColor;
  final VoidCallback onTap;

  const _MemberTile({
    required this.name,
    required this.isCurrentUser,
    required this.isHost,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? context.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(JetlagRadii.sm),
          border: isCurrentUser
              ? Border.all(color: context.accent.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: accentColor.withValues(alpha: 0.2),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name + (isCurrentUser ? ' (you)' : ''),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isCurrentUser ? FontWeight.w600 : FontWeight.w400,
                  color: isCurrentUser
                      ? context.accent
                      : context.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isHost)
              Icon(Icons.star_rounded,
                  size: 14, color: context.orange),
          ],
        ),
      ),
    );
  }
}
