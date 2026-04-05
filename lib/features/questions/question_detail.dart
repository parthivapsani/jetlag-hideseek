import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/jetlag_badge.dart';
import '../../design/widgets/jetlag_button.dart';
import '../../design/widgets/jetlag_card.dart';
import '../../design/widgets/jetlag_input.dart';

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
                  color: context.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Category chip + test badge
            Row(
              children: [
                _CategoryBadge(category: widget.question.category),
                const Spacer(),
                if (widget.testMode)
                  JetlagBadge(
                    label: 'Test Mode',
                    color: JetlagBadgeColor.orange,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Question text
            Text(
              widget.question.text,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Stats
            Row(
              children: [
                _StatBox(
                  icon: Icons.style,
                  value: '${widget.question.cardsDraw}',
                  label: 'Draw',
                ),
                const SizedBox(width: 12),
                _StatBox(
                  icon: Icons.check_circle,
                  value: '${widget.question.cardsKeep}',
                  label: 'Keep',
                ),
                const SizedBox(width: 12),
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
                  color: context.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(JetlagRadii.sm),
                ),
                child: Text(
                  widget.question.rules!,
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Custom value input
            if (widget.question.text.contains('[')) ...[
              JetlagInput(
                label: 'Customize Question',
                hint: _getPlaceholderHint(),
                controller: _customValueController,
              ),
              const SizedBox(height: 24),
            ],

            // Ask button
            JetlagButton(
              label: widget.testMode ? 'Ask (Test Mode)' : 'Ask Question',
              icon: Icons.send,
              variant: widget.testMode
                  ? JetlagButtonVariant.secondary
                  : JetlagButtonVariant.primary,
              isLoading: _isAsking,
              onPressed: widget.canAsk && !_isAsking ? _askQuestion : null,
            ),

            if (!widget.canAsk && !widget.testMode)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Category is on cooldown',
                  style: TextStyle(color: context.orange, fontSize: 13),
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
        border: Border.all(color: context.border),
        borderRadius: BorderRadius.circular(JetlagRadii.sm),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Answer Type',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: context.textTertiary,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
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

class _CategoryBadge extends StatelessWidget {
  final QuestionCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final badgeColor = switch (category) {
      QuestionCategory.matching => JetlagBadgeColor.blue,
      QuestionCategory.measuring => JetlagBadgeColor.purple,
      QuestionCategory.radar => JetlagBadgeColor.green,
      QuestionCategory.thermometer => JetlagBadgeColor.orange,
      QuestionCategory.tentacles => JetlagBadgeColor.blue,
      QuestionCategory.photo => JetlagBadgeColor.red,
    };

    return JetlagBadge(
      label: category.displayName,
      color: badgeColor,
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
          color: context.surface2,
          borderRadius: BorderRadius.circular(JetlagRadii.sm),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: context.textSecondary),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: context.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
