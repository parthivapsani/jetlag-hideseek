import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';

/// Screen shown when hider needs to draw and keep cards after answering a question
class CardDrawScreen extends ConsumerStatefulWidget {
  final QuestionCategory category;
  final int drawCount;
  final int keepCount;
  final VoidCallback? onComplete;

  const CardDrawScreen({
    super.key,
    required this.category,
    required this.drawCount,
    required this.keepCount,
    this.onComplete,
  });

  @override
  ConsumerState<CardDrawScreen> createState() => _CardDrawScreenState();
}

class _CardDrawScreenState extends ConsumerState<CardDrawScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  List<GameCard> _drawnCards = [];
  Set<int> _selectedIndices = {};
  bool _isDrawing = true;
  bool _isRevealing = false;
  int _revealedCount = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _startDrawing();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startDrawing() async {
    // Draw cards from deck
    final cardActions = ref.read(cardActionsProvider);
    final drawnCards = <GameCard>[];

    for (int i = 0; i < widget.drawCount; i++) {
      final card = cardActions.drawRandomCard();
      if (card != null) {
        drawnCards.add(card);
      }
    }

    setState(() {
      _drawnCards = drawnCards;
      _isDrawing = false;
      _isRevealing = true;
    });

    // Reveal cards one by one
    for (int i = 0; i < _drawnCards.length; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _revealedCount = i + 1;
        });
      }
    }

    setState(() {
      _isRevealing = false;
    });
  }

  void _toggleSelection(int index) {
    if (_isRevealing) return;

    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        if (_selectedIndices.length < widget.keepCount) {
          _selectedIndices.add(index);
        } else {
          // Replace oldest selection
          final oldest = _selectedIndices.first;
          _selectedIndices.remove(oldest);
          _selectedIndices.add(index);
        }
      }
    });
  }

  bool get _canConfirm =>
      !_isRevealing && _selectedIndices.length == widget.keepCount;

  void _confirmSelection() async {
    if (!_canConfirm) return;

    final cardActions = ref.read(cardActionsProvider);

    // Keep selected cards, discard others
    for (int i = 0; i < _drawnCards.length; i++) {
      final card = _drawnCards[i];
      if (_selectedIndices.contains(i)) {
        await cardActions.keepCard(card.id);
      } else {
        await cardActions.discardDrawnCard(card.id);
      }
    }

    widget.onComplete?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    '${widget.category.displayName} Question Answered!',
                    style: TextStyle(
                      color: JetLagTheme.getCategoryColor(widget.category.displayName),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isDrawing
                        ? 'Drawing cards...'
                        : _isRevealing
                            ? 'Revealing cards...'
                            : 'Pick ${widget.keepCount} card${widget.keepCount > 1 ? 's' : ''} to keep',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Draw ${widget.drawCount}, Keep ${widget.keepCount}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Cards
            Expanded(
              child: _isDrawing
                  ? _buildDrawingState()
                  : _buildCardSelection(),
            ),

            // Selection indicator & confirm button
            if (!_isDrawing)
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Selection count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.keepCount, (i) {
                        final isFilled = i < _selectedIndices.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? Colors.green : Colors.grey[700],
                            border: Border.all(
                              color: isFilled ? Colors.green : Colors.grey[500]!,
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canConfirm ? _confirmSelection : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          disabledBackgroundColor: Colors.grey[800],
                        ),
                        child: Text(
                          _canConfirm
                              ? 'Confirm Selection'
                              : 'Select ${widget.keepCount - _selectedIndices.length} more',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 24),
          Text(
            'Drawing ${widget.drawCount} cards...',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.drawCount <= 2 ? 2 : 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _drawnCards.length,
        itemBuilder: (context, index) {
          final isRevealed = index < _revealedCount;
          final isSelected = _selectedIndices.contains(index);

          if (!isRevealed) {
            return _CardBack();
          }

          return _SelectableCard(
            card: _drawnCards[index],
            isSelected: isSelected,
            onTap: () => _toggleSelection(index),
          );
        },
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: JetLagTheme.primaryBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.style,
              color: Colors.white.withOpacity(0.5),
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              'JET LAG',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  final GameCard card;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableCard({
    required this.card,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getCardColor(card.type);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.transparent,
            width: 4,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Stack(
          children: [
            // Card content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getTypeName(card.type),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Card name
                  Text(
                    card.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Description
                  Expanded(
                    child: Text(
                      card.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Effect
                  if (card.effect != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        card.effect!,
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Selected checkmark
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCardColor(CardType type) {
    switch (type) {
      case CardType.timeBonus:
        return JetLagTheme.timeBonusColor;
      case CardType.powerup:
        return JetLagTheme.powerupColor;
      case CardType.curse:
        return JetLagTheme.curseColor;
      case CardType.timeTrap:
        return JetLagTheme.timeTrapColor;
    }
  }

  String _getTypeName(CardType type) {
    switch (type) {
      case CardType.timeBonus:
        return 'TIME BONUS';
      case CardType.powerup:
        return 'POWERUP';
      case CardType.curse:
        return 'CURSE';
      case CardType.timeTrap:
        return 'TIME TRAP';
    }
  }
}

/// Show the card draw screen as a modal
Future<void> showCardDrawScreen(
  BuildContext context, {
  required QuestionCategory category,
  required int drawCount,
  required int keepCount,
  VoidCallback? onComplete,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => CardDrawScreen(
        category: category,
        drawCount: drawCount,
        keepCount: keepCount,
        onComplete: onComplete,
      ),
    ),
  );
}
