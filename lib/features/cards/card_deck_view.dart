import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
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
          color: Theme.of(context).colorScheme.primaryContainer,
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
                color: Colors.green,
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
              ? _buildEmptyState()
              : _buildCardGrid(context, ref, handWithDetails),
        ),

        // Draw card button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Cards are drawn when seekers ask questions',
            style: TextStyle(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.style_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No cards in hand',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll draw cards when seekers ask questions',
            style: TextStyle(
              color: Colors.grey[500],
            ),
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
    // Group cards by type
    final timeBonuses = cards.where((c) => c.$2.type == CardType.timeBonus).toList();
    final powerups = cards.where((c) => c.$2.type == CardType.powerup).toList();
    final curses = cards.where((c) => c.$2.type == CardType.curse).toList();
    final timeTraps = cards.where((c) => c.$2.type == CardType.timeTrap).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (timeBonuses.isNotEmpty) ...[
          _SectionHeader(title: 'Time Bonuses', count: timeBonuses.length),
          ...timeBonuses.map((card) => _CardTile(
                hiderCard: card.$1,
                gameCard: card.$2,
              )),
          const SizedBox(height: 16),
        ],
        if (powerups.isNotEmpty) ...[
          _SectionHeader(title: 'Powerups', count: powerups.length),
          ...powerups.map((card) => _CardTile(
                hiderCard: card.$1,
                gameCard: card.$2,
              )),
          const SizedBox(height: 16),
        ],
        if (curses.isNotEmpty) ...[
          _SectionHeader(title: 'Curses (to play on yourself)', count: curses.length),
          ...curses.map((card) => _CardTile(
                hiderCard: card.$1,
                gameCard: card.$2,
              )),
          const SizedBox(height: 16),
        ],
        if (timeTraps.isNotEmpty) ...[
          _SectionHeader(title: 'Time Traps', count: timeTraps.length),
          ...timeTraps.map((card) => _CardTile(
                hiderCard: card.$1,
                gameCard: card.$2,
              )),
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
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
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
      color: Colors.red.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Active Curses',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
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
                    child: Text(card.name),
                  ),
                  if (curse.expiresAt != null)
                    Text(
                      _formatRemainingTime(curse.remainingDuration),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
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

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 12),
            ),
          ),
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
    final color = _getCardColor(gameCard.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showCardDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      gameCard.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
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

  void _showCardDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CardDetail(
        hiderCard: hiderCard,
        gameCard: gameCard,
      ),
    );
  }
}
