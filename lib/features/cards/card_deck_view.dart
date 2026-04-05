import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/jetlag_badge.dart';
import '../../design/widgets/jetlag_card.dart';
import 'card_detail.dart';

class CardDeckView extends ConsumerWidget {
  const CardDeckView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handWithDetails = ref.watch(handWithDetailsProvider);
    final activeCursesAsync = ref.watch(activeCursesProvider);
    final effectiveTime = ref.watch(effectiveHidingTimeProvider);
    final session = ref.watch(currentSessionProvider).valueOrNull;

    return Column(
      children: [
        // Time summary
        Container(
          padding: const EdgeInsets.all(16),
          color: context.accent.withValues(alpha: 0.08),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TimeStat(
                label: 'Base Time',
                value: _formatDuration(session?.hidingPeriodDuration ?? Duration.zero),
              ),
              _TimeStat(
                label: 'Bonuses',
                value: '+${_formatDuration(effectiveTime - (session?.hidingPeriodDuration ?? Duration.zero))}',
                color: context.green,
              ),
              _TimeStat(
                label: 'Effective',
                value: _formatDuration(effectiveTime),
                isBold: true,
              ),
            ],
          ),
        ),

        // Active curses
        activeCursesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (curses) {
            if (curses.isEmpty) return const SizedBox.shrink();
            return _ActiveCursesSection(curses: curses);
          },
        ),

        // Cards in hand
        Expanded(
          child: handWithDetails.isEmpty
              ? _buildEmptyState(context)
              : _buildCardGrid(context, ref, handWithDetails),
        ),

        // Draw card hint
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Cards are drawn when seekers ask questions',
            style: TextStyle(
              color: context.textTertiary,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.style_outlined, size: 64, color: context.textTertiary),
          const SizedBox(height: 16),
          Text(
            'No cards in hand',
            style: TextStyle(fontSize: 18, color: context.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll draw cards when seekers ask questions',
            style: TextStyle(color: context.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGrid(
    BuildContext context,
    WidgetRef ref,
    List<(HiderCard, GameCard)> cards,
  ) {
    final timeBonuses = cards.where((c) => c.$2.type == CardType.timeBonus).toList();
    final powerups = cards.where((c) => c.$2.type == CardType.powerup).toList();
    final curses = cards.where((c) => c.$2.type == CardType.curse).toList();
    final timeTraps = cards.where((c) => c.$2.type == CardType.timeTrap).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (timeBonuses.isNotEmpty) ...[
          _SectionHeader(title: 'Time Bonuses', count: timeBonuses.length, badgeColor: JetlagBadgeColor.green),
          ...timeBonuses.map((card) => _CardTile(hiderCard: card.$1, gameCard: card.$2)),
          const SizedBox(height: 16),
        ],
        if (powerups.isNotEmpty) ...[
          _SectionHeader(title: 'Powerups', count: powerups.length, badgeColor: JetlagBadgeColor.blue),
          ...powerups.map((card) => _CardTile(hiderCard: card.$1, gameCard: card.$2)),
          const SizedBox(height: 16),
        ],
        if (curses.isNotEmpty) ...[
          _SectionHeader(title: 'Curses (to play on yourself)', count: curses.length, badgeColor: JetlagBadgeColor.red),
          ...curses.map((card) => _CardTile(hiderCard: card.$1, gameCard: card.$2)),
          const SizedBox(height: 16),
        ],
        if (timeTraps.isNotEmpty) ...[
          _SectionHeader(title: 'Time Traps', count: timeTraps.length, badgeColor: JetlagBadgeColor.purple),
          ...timeTraps.map((card) => _CardTile(hiderCard: card.$1, gameCard: card.$2)),
        ],
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _TimeStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool isBold;

  const _TimeStat({
    required this.label,
    required this.value,
    this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.textTertiary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: color ?? context.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ActiveCursesSection extends ConsumerWidget {
  final List<ActiveCurse> curses;

  const _ActiveCursesSection({required this.curses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCards = ref.watch(allCardsProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      color: context.red.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: context.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'Active Curses',
                style: TextStyle(fontWeight: FontWeight.w700, color: context.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...curses.map((curse) {
            final card = allCards.firstWhere(
              (c) => c.id == curse.cardId,
              orElse: () => GameCard(
                id: curse.cardId,
                name: 'Unknown',
                description: 'Unknown curse',
                type: CardType.curse,
              ),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(card.name, style: TextStyle(color: context.textPrimary)),
                  ),
                  if (curse.expiresAt != null)
                    Text(
                      _formatRemainingTime(curse.remainingDuration),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: context.red,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatRemainingTime(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final JetlagBadgeColor badgeColor;

  const _SectionHeader({required this.title, required this.count, required this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          JetlagBadge(label: '$count', color: badgeColor),
        ],
      ),
    );
  }
}

class _CardTile extends ConsumerWidget {
  final HiderCard hiderCard;
  final GameCard gameCard;

  const _CardTile({
    required this.hiderCard,
    required this.gameCard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _getCardColor(context, gameCard.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: JetlagCard(
        onTap: () => _showCardDetail(context),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameCard.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: context.textPrimary,
                    ),
                  ),
                  Text(
                    gameCard.description,
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  Color _getCardColor(BuildContext context, CardType type) {
    switch (type) {
      case CardType.timeBonus:
        return context.green;
      case CardType.powerup:
        return context.accent;
      case CardType.curse:
        return context.red;
      case CardType.timeTrap:
        return context.purple;
    }
  }

  void _showCardDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      builder: (context) => CardDetail(
        hiderCard: hiderCard,
        gameCard: gameCard,
      ),
    );
  }
}
