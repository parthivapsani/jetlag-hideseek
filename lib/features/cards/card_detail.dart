import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/jetlag_badge.dart';
import '../../design/widgets/jetlag_button.dart';

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
                  color: context.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Card type badge
            Row(
              children: [
                JetlagBadge(
                  label: _getCardTypeName(widget.gameCard.type),
                  color: _getBadgeColor(widget.gameCard.type),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card name
            Text(
              widget.gameCard.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              widget.gameCard.description,
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
            const SizedBox(height: 24),

            // Card-specific info
            _buildCardInfo(),
            const SizedBox(height: 24),

            // Rules
            if (widget.gameCard.rules != null) ...[
              Text(
                'Rules',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.surface2,
                  borderRadius: BorderRadius.circular(JetlagRadii.sm),
                ),
                child: Text(
                  widget.gameCard.rules!,
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
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
          color: context.green,
        );

      case CardType.powerup:
        return _InfoCard(
          icon: Icons.flash_on,
          title: 'Effect',
          content: _getPowerupDescription(card.powerupEffect),
          color: context.accent,
        );

      case CardType.curse:
        return Column(
          children: [
            _InfoCard(
              icon: Icons.warning,
              title: 'Curse Effect',
              content: _getCurseDescription(card.curseType),
              color: context.red,
            ),
            if (card.curseDurationMinutes != null) ...[
              const SizedBox(height: 12),
              _InfoCard(
                icon: Icons.timer,
                title: 'Duration',
                content: '${card.curseDurationMinutes} minutes',
                color: context.orange,
              ),
            ],
            if (card.isBlocking) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(JetlagRadii.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block, color: context.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'This curse blocks card play',
                      style: TextStyle(color: context.red, fontSize: 13),
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
          color: context.purple,
        );
    }
  }

  Widget _buildActionButtons(bool isBlocked) {
    final card = widget.gameCard;

    // Time bonuses are automatic
    if (card.type == CardType.timeBonus) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(JetlagRadii.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: context.green, size: 20),
            const SizedBox(width: 8),
            Text(
              'Bonus applies automatically',
              style: TextStyle(color: context.green, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final canPlay = !isBlocked && _canPlayCard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JetlagButton(
          label: _getPlayButtonText(),
          variant: JetlagButtonVariant.primary,
          isLoading: _isPlaying,
          onPressed: canPlay && !_isPlaying ? _playCard : null,
        ),
        if (!canPlay && isBlocked)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Cannot play while a blocking curse is active',
              style: TextStyle(color: context.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 12),
        JetlagButton(
          label: 'Discard',
          variant: JetlagButtonVariant.secondary,
          onPressed: !_isPlaying ? _discardCard : null,
        ),
      ],
    );
  }

  bool _canPlayCard() {
    final card = widget.gameCard;
    if (card.playCondition != null) {
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
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surface,
        title: Text('Discard Card?', style: TextStyle(color: ctx.textPrimary)),
        content: Text(
          'Are you sure you want to discard ${widget.gameCard.name}?',
          style: TextStyle(color: ctx.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ctx.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard', style: TextStyle(color: ctx.red)),
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

  JetlagBadgeColor _getBadgeColor(CardType type) {
    switch (type) {
      case CardType.timeBonus:
        return JetlagBadgeColor.green;
      case CardType.powerup:
        return JetlagBadgeColor.blue;
      case CardType.curse:
        return JetlagBadgeColor.red;
      case CardType.timeTrap:
        return JetlagBadgeColor.purple;
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(JetlagRadii.lg),
        border: Border.all(color: color.withValues(alpha: 0.25)),
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
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
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
