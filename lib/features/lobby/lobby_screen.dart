import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../app/theme.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const LobbyScreen({super.key, required this.sessionId});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _hasJoined = false;
  ParticipantRole _selectedRole = ParticipantRole.seeker;

  @override
  void initState() {
    super.initState();
    ref.read(currentSessionIdProvider.notifier).state = widget.sessionId;
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(currentSessionProvider);
    final participantsAsync = ref.watch(participantsProvider);
    final currentParticipant = ref.watch(currentParticipantProvider);

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
                  const Text('Game not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            ),
          );
        }

        // Redirect if game has started
        if (session.status != SessionStatus.waiting && currentParticipant != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToGame(currentParticipant.role);
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Game Lobby'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _leaveLobby(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copyRoomCode(session.roomCode),
                tooltip: 'Copy room code',
              ),
            ],
          ),
          body: Column(
            children: [
              // Room Code Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Column(
                  children: [
                    const Text('Room Code'),
                    const SizedBox(height: 8),
                    Text(
                      session.roomCode,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share this code with other players',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: !_hasJoined
                    ? _buildJoinSection()
                    : _buildParticipantsList(participantsAsync, currentParticipant),
              ),

              // Start Game Button (host only)
              if (_hasJoined && currentParticipant?.isHost == true)
                _buildStartButton(participantsAsync),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJoinSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select Your Role',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Role Selection
          _RoleCard(
            role: ParticipantRole.seeker,
            isSelected: _selectedRole == ParticipantRole.seeker,
            onTap: () => setState(() => _selectedRole = ParticipantRole.seeker),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            role: ParticipantRole.hider,
            isSelected: _selectedRole == ParticipantRole.hider,
            onTap: () => setState(() => _selectedRole = ParticipantRole.hider),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            role: ParticipantRole.spectator,
            isSelected: _selectedRole == ParticipantRole.spectator,
            onTap: () => setState(() => _selectedRole = ParticipantRole.spectator),
          ),
          const Spacer(),

          ElevatedButton(
            onPressed: _joinGame,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Join Game', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList(
    AsyncValue<List<Participant>> participantsAsync,
    Participant? currentParticipant,
  ) {
    return participantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (participants) {
        final hiders = participants.where((p) => p.role == ParticipantRole.hider).toList();
        final seekers = participants.where((p) => p.role == ParticipantRole.seeker).toList();
        final spectators = participants.where((p) => p.role == ParticipantRole.spectator).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (hiders.isNotEmpty) ...[
              _buildRoleHeader('Hider', JetLagTheme.hiderGreen, hiders.length),
              ...hiders.map((p) => _ParticipantTile(
                    participant: p,
                    isCurrentUser: p.id == currentParticipant?.id,
                  )),
              const SizedBox(height: 16),
            ],
            if (seekers.isNotEmpty) ...[
              _buildRoleHeader('Seekers', JetLagTheme.seekerRed, seekers.length),
              ...seekers.map((p) => _ParticipantTile(
                    participant: p,
                    isCurrentUser: p.id == currentParticipant?.id,
                  )),
              const SizedBox(height: 16),
            ],
            if (spectators.isNotEmpty) ...[
              _buildRoleHeader('Spectators', Colors.grey, spectators.length),
              ...spectators.map((p) => _ParticipantTile(
                    participant: p,
                    isCurrentUser: p.id == currentParticipant?.id,
                  )),
            ],

            // Change Role Button
            if (currentParticipant != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => _showChangeRoleDialog(currentParticipant),
                child: const Text('Change Role'),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRoleHeader(String title, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(AsyncValue<List<Participant>> participantsAsync) {
    return participantsAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (participants) {
        final hasHider = participants.any((p) => p.role == ParticipantRole.hider);
        final hasSeekers = participants.any((p) => p.role == ParticipantRole.seeker);
        final canStart = hasHider && hasSeekers;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!canStart)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    !hasHider
                        ? 'Need a hider to start'
                        : 'Need at least one seeker',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed: canStart ? _startGame : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: JetLagTheme.hiderGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Start Hiding Period',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _joinGame() async {
    final displayName = ref.read(displayNameProvider) ?? 'Player';
    final session = ref.read(currentSessionProvider).valueOrNull;
    final isHost = session?.createdBy == await ref.read(deviceTokenProvider.future);

    try {
      await ref.read(gameActionsProvider).joinAsParticipant(
            displayName: displayName,
            role: _selectedRole,
            isHost: isHost,
          );
      setState(() {
        _hasJoined = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining: $e')),
        );
      }
    }
  }

  void _showChangeRoleDialog(Participant current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ParticipantRole.values.map((role) {
            return ListTile(
              title: Text(_getRoleName(role)),
              leading: Radio<ParticipantRole>(
                value: role,
                groupValue: current.role,
                onChanged: (value) async {
                  if (value != null) {
                    await ref.read(gameActionsProvider).updateRole(value);
                    if (mounted) Navigator.pop(context);
                  }
                },
              ),
              onTap: () async {
                await ref.read(gameActionsProvider).updateRole(role);
                if (mounted) Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _startGame() async {
    try {
      await ref.read(gameActionsProvider).startHidingPeriod();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting game: $e')),
        );
      }
    }
  }

  void _navigateToGame(ParticipantRole role) {
    final sessionId = widget.sessionId;
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
    await ref.read(gameActionsProvider).leaveSession();
    if (mounted) {
      context.go('/');
    }
  }

  void _copyRoomCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room code copied!')),
    );
  }

  String _getRoleName(ParticipantRole role) {
    switch (role) {
      case ParticipantRole.hider:
        return 'Hider';
      case ParticipantRole.seeker:
        return 'Seeker';
      case ParticipantRole.spectator:
        return 'Spectator';
    }
  }
}

class _RoleCard extends StatelessWidget {
  final ParticipantRole role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      ParticipantRole.hider => JetLagTheme.hiderGreen,
      ParticipantRole.seeker => JetLagTheme.seekerRed,
      ParticipantRole.spectator => Colors.grey,
    };

    final icon = switch (role) {
      ParticipantRole.hider => Icons.visibility_off,
      ParticipantRole.seeker => Icons.search,
      ParticipantRole.spectator => Icons.remove_red_eye,
    };

    final description = switch (role) {
      ParticipantRole.hider => 'Hide from the seekers and survive the clock',
      ParticipantRole.seeker => 'Find the hider before time runs out',
      ParticipantRole.spectator => 'Watch the game unfold',
    };

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.name[0].toUpperCase() + role.name.substring(1),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Participant participant;
  final bool isCurrentUser;

  const _ParticipantTile({
    required this.participant,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: participant.isConnected ? Colors.green : Colors.grey,
          child: Text(
            participant.displayName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Row(
          children: [
            Text(participant.displayName),
            if (isCurrentUser)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  '(you)',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            if (participant.isHost)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.star, size: 16, color: Colors.amber),
              ),
          ],
        ),
        subtitle: Text(participant.isConnected ? 'Connected' : 'Disconnected'),
      ),
    );
  }
}
