import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';

class CardDetail extends ConsumerStatefulWidget {
  final HiderCard hiderCard;
  final GameCard gameCard;

  const CardDetail({
    super.key,
    required this.hiderCard,
    required this.gameCard,
  });

  @override
  ConsumerState<CardDetail> createState() => _CardDetailState();
}

class _CardDetailState extends ConsumerState<CardDetail> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final color = _getCardColor(widget.gameCard.type);
    final isBlocked = ref.watch(isBlockedByCurseProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
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

            // Card type badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getCardTypeName(widget.gameCard.type),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card name
            Text(
              widget.gameCard.name,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              widget.gameCard.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),

            // Card-specific info
            _buildCardInfo(),
            const SizedBox(height: 24),

            // Rules
            if (widget.gameCard.rules != null) ...[
              const Text(
                'Rules',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.gameCard.rules!),
              ),
              const SizedBox(height: 24),
            ],

            // Action buttons
            _buildActionButtons(isBlocked),
          ],
        ),
      ),
    );
  }

  Widget _buildCardInfo() {
    final card = widget.gameCard;

    switch (card.type) {
      case CardType.timeBonus:
        return _InfoCard(
          icon: Icons.timer,
          title: 'Time Bonus',
          content: card.timeBonusMinutes != null
              ? '+${card.timeBonusMinutes} minutes'
              : '+${(card.timeBonusPercentage! * 100).toInt()}%',
          color: Colors.green,
        );

      case CardType.powerup:
        return _InfoCard(
          icon: Icons.flash_on,
          title: 'Effect',
          content: _getPowerupDescription(card.powerupEffect),
          color: Colors.blue,
        );

      case CardType.curse:
        return Column(
          children: [
            _InfoCard(
              icon: Icons.warning,
              title: 'Curse Effect',
              content: _getCurseDescription(card.curseType),
              color: Colors.red,
            ),
            if (card.curseDurationMinutes != null) ...[
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.timer,
                title: 'Duration',
                content: '${card.curseDurationMinutes} minutes',
                color: Colors.orange,
              ),
            ],
            if (card.isBlocking) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.block, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'This curse blocks card play',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );

      case CardType.timeTrap:
        return _InfoCard(
          icon: Icons.location_on,
          title: 'Trap Bonus',
          content: '+${card.trapBonusPerHourMinutes} minutes per hour untriggered',
          color: Colors.purple,
        );
    }
  }

  Widget _buildActionButtons(bool isBlocked) {
    final card = widget.gameCard;

    // Time bonuses are automatic - no action needed
    if (card.type == CardType.timeBonus) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.green),
            SizedBox(width: 8),
            Text(
              'Bonus applies automatically',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
      );
    }

    // Check if card can be played
    final canPlay = !isBlocked && _canPlayCard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: canPlay && !_isPlaying ? _playCard : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: _getCardColor(card.type),
            foregroundColor: Colors.white,
          ),
          child: _isPlaying
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _getPlayButtonText(),
                  style: const TextStyle(fontSize: 18),
                ),
        ),
        if (!canPlay && isBlocked)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Cannot play while a blocking curse is active',
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: !_isPlaying ? _discardCard : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Discard'),
        ),
      ],
    );
  }

  bool _canPlayCard() {
    final card = widget.gameCard;

    // Check play conditions
    if (card.playCondition != null) {
      // TODO: Implement condition checking
      return true;
    }

    return true;
  }

  String _getPlayButtonText() {
    switch (widget.gameCard.type) {
      case CardType.timeBonus:
        return 'Automatic';
      case CardType.powerup:
        return 'Use Powerup';
      case CardType.curse:
        return 'Apply Curse';
      case CardType.timeTrap:
        return 'Place Trap';
    }
  }

  Future<void> _playCard() async {
    setState(() => _isPlaying = true);

    try {
      final cardActions = ref.read(cardActionsProvider);

      if (widget.gameCard.type == CardType.curse) {
        // Activate curse
        await cardActions.activateCurse(
          cardId: widget.gameCard.id,
          curseType: widget.gameCard.curseType!,
          durationMinutes: widget.gameCard.curseDurationMinutes,
          condition: widget.gameCard.curseCondition,
          isBlocking: widget.gameCard.isBlocking,
        );
      }

      await cardActions.playCard(widget.hiderCard.id, widget.gameCard.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.gameCard.name} played!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  Future<void> _discardCard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Card?'),
        content: Text(
          'Are you sure you want to discard ${widget.gameCard.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(cardActionsProvider).discardCard(
            widget.hiderCard.id,
            widget.gameCard.id,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.gameCard.name} discarded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Color _getCardColor(CardType type) {
    switch (type) {
      case CardType.timeBonus:
        return Colors.green;
      case CardType.powerup:
        return Colors.blue;
      case CardType.curse:
        return Colors.red;
      case CardType.timeTrap:
        return Colors.purple;
    }
  }

  String _getCardTypeName(CardType type) {
    switch (type) {
      case CardType.timeBonus:
        return 'Time Bonus';
      case CardType.powerup:
        return 'Powerup';
      case CardType.curse:
        return 'Curse';
      case CardType.timeTrap:
        return 'Time Trap';
    }
  }

  String _getPowerupDescription(String? effect) {
    switch (effect) {
      case 'veto_question':
        return 'Cancel the current question';
      case 'randomize_question':
        return 'Force a random question';
      case 'discard_draw':
        return 'Discard and redraw cards';
      case 'move':
        return 'Move to a new hiding zone';
      case 'duplicate':
        return 'Copy another card\'s effect';
      default:
        return 'Special effect';
    }
  }

  String _getCurseDescription(CurseType? type) {
    switch (type) {
      case CurseType.expressRoute:
        return 'Must stay on current transit';
      case CurseType.longShot:
        return 'Frozen until next question answered';
      case CurseType.runner:
        return 'Must move a minimum distance';
      case CurseType.museum:
        return 'Cannot move from current position';
      default:
        return 'Restricts your movement';
    }
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
