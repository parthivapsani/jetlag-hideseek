import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';

class QuestionDetail extends ConsumerStatefulWidget {
  final Question question;
  final bool canAsk;
  final bool testMode;

  const QuestionDetail({
    super.key,
    required this.question,
    required this.canAsk,
    required this.testMode,
  });

  @override
  ConsumerState<QuestionDetail> createState() => _QuestionDetailState();
}

class _QuestionDetailState extends ConsumerState<QuestionDetail> {
  bool _isAsking = false;
  final _customValueController = TextEditingController();

  @override
  void dispose() {
    _customValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

            // Category chip
            Row(
              children: [
                _CategoryChip(category: widget.question.category),
                const Spacer(),
                if (widget.testMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TEST MODE',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Question text
            Text(
              widget.question.text,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            // Stats
            Row(
              children: [
                _StatBox(
                  icon: Icons.monetization_on,
                  value: '${widget.question.coinCost}',
                  label: 'Coins',
                ),
                const SizedBox(width: 16),
                _StatBox(
                  icon: Icons.style,
                  value: '${widget.question.cardsDrawn}',
                  label: 'Cards',
                ),
                const SizedBox(width: 16),
                _StatBox(
                  icon: Icons.timer,
                  value: '${widget.question.responseTimeMinutes}',
                  label: 'Minutes',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Answer type info
            _buildAnswerTypeInfo(),
            const SizedBox(height: 16),

            // Rules
            if (widget.question.rules != null) ...[
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.question.rules!),
              ),
              const SizedBox(height: 24),
            ],

            // Custom value input (for questions with placeholders)
            if (widget.question.text.contains('[')) ...[
              const Text(
                'Customize Question',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customValueController,
                decoration: InputDecoration(
                  hintText: _getPlaceholderHint(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Ask button
            ElevatedButton(
              onPressed: widget.canAsk && !_isAsking ? _askQuestion : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: widget.testMode ? Colors.orange : null,
              ),
              child: _isAsking
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.testMode ? 'Ask (Test Mode)' : 'Ask Question',
                      style: const TextStyle(fontSize: 18),
                    ),
            ),

            if (!widget.canAsk && !widget.testMode)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Category is on cooldown',
                  style: TextStyle(
                    color: Colors.orange[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerTypeInfo() {
    final (icon, description) = switch (widget.question.answerType) {
      AnswerType.text => (Icons.text_fields, 'Hider will respond with text'),
      AnswerType.photo => (Icons.photo_camera, 'Hider will send a photo'),
      AnswerType.audio => (Icons.mic, 'Hider will send an audio recording'),
      AnswerType.boolean => (Icons.check_circle, 'Hider will answer Yes or No'),
      AnswerType.number => (Icons.numbers, 'Hider will respond with a number'),
      AnswerType.direction =>
        (Icons.explore, 'Hider will respond with a direction'),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Answer Type',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPlaceholderHint() {
    final text = widget.question.text;
    final match = RegExp(r'\[([^\]]+)\]').firstMatch(text);
    return match?.group(1) ?? 'Enter value';
  }

  Future<void> _askQuestion() async {
    setState(() => _isAsking = true);

    try {
      await ref.read(questionActionsProvider).askQuestion(
            questionId: widget.question.id,
            category: widget.question.category,
            responseTimeMinutes: widget.question.responseTimeMinutes,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.testMode
                  ? 'Test question sent!'
                  : 'Question sent to hider!',
            ),
          ),
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
        setState(() => _isAsking = false);
      }
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final QuestionCategory category;

  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = switch (category) {
      QuestionCategory.matching => Colors.blue,
      QuestionCategory.measuring => Colors.purple,
      QuestionCategory.radar => Colors.green,
      QuestionCategory.thermometer => Colors.orange,
      QuestionCategory.tentacles => Colors.teal,
      QuestionCategory.photo => Colors.pink,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.displayName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
