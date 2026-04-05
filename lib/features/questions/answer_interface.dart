import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/supabase_init.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/jetlag_badge.dart';
import '../../design/widgets/jetlag_button.dart';
import '../../design/widgets/jetlag_card.dart';
import '../../design/widgets/jetlag_input.dart';
import '../cards/card_draw_screen.dart';

class AnswerInterface extends ConsumerStatefulWidget {
  final SessionQuestion sessionQuestion;

  const AnswerInterface({super.key, required this.sessionQuestion});

  @override
  ConsumerState<AnswerInterface> createState() => _AnswerInterfaceState();
}

class _AnswerInterfaceState extends ConsumerState<AnswerInterface> {
  final _textController = TextEditingController();
  String? _selectedOption;
  XFile? _photoFile;
  Uint8List? _photoBytes;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allQuestions = ref.watch(allQuestionsProvider);
    final question = allQuestions.firstWhere(
      (q) => q.id == widget.sessionQuestion.questionId,
      orElse: () => Question(
        id: widget.sessionQuestion.questionId,
        text: 'Unknown question',
        category: widget.sessionQuestion.category,
        cardsDraw: widget.sessionQuestion.category.cardsDraw,
        cardsKeep: widget.sessionQuestion.category.cardsKeep,
        responseTimeMinutes: 5,
        answerType: AnswerType.text,
      ),
    );

    final remainingTime =
        widget.sessionQuestion.responseDeadline.difference(DateTime.now());
    final isUrgent = remainingTime.inMinutes < 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isUrgent ? context.red : context.accent).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(JetlagRadii.lg),
              border: Border.all(
                color: (isUrgent ? context.red : context.accent).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer,
                  color: isUrgent ? context.red : context.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  'Time Remaining: ${_formatDuration(remainingTime)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isUrgent ? context.red : context.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Question
          Text(
            question.text,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.sessionQuestion.category.displayName,
            style: TextStyle(
              color: _getCategoryColor(widget.sessionQuestion.category),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          // Rules
          if (question.rules != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(JetlagRadii.sm),
                border: Border.all(color: context.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info, color: context.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.rules!,
                      style: TextStyle(color: context.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Answer input based on type
          _buildAnswerInput(question),
          const SizedBox(height: 24),

          // Submit button
          JetlagButton(
            label: 'Submit Answer',
            icon: Icons.check,
            variant: JetlagButtonVariant.primary,
            isLoading: _isSubmitting,
            onPressed: _canSubmit(question) && !_isSubmitting
                ? () => _submitAnswer(question)
                : null,
          ),
          const SizedBox(height: 16),

          // Veto option
          _buildVetoOption(),
        ],
      ),
    );
  }

  Widget _buildAnswerInput(Question question) {
    switch (question.answerType) {
      case AnswerType.text:
        return JetlagInput(
          label: 'Your Answer',
          hint: 'Type your answer here...',
          controller: _textController,
          maxLines: 3,
        );

      case AnswerType.boolean:
      case AnswerType.direction:
        final options = question.options ?? ['Yes', 'No'];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = _selectedOption == option;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedOption = isSelected ? null : option;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.accent.withValues(alpha: 0.15)
                      : context.surface2,
                  borderRadius: BorderRadius.circular(JetlagRadii.sm),
                  border: Border.all(
                    color: isSelected ? context.accent : context.border,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? context.accent : context.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        );

      case AnswerType.number:
        return JetlagInput(
          label: 'Your Answer',
          hint: 'Enter a number...',
          controller: _textController,
          keyboardType: TextInputType.number,
        );

      case AnswerType.photo:
        return Column(
          children: [
            if (_photoBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(JetlagRadii.lg),
                child: Image.memory(
                  _photoBytes!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: JetlagButton(
                    label: 'Take Photo',
                    icon: Icons.camera_alt,
                    variant: JetlagButtonVariant.secondary,
                    onPressed: () => _pickPhoto(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: JetlagButton(
                    label: 'Gallery',
                    icon: Icons.photo_library,
                    variant: JetlagButtonVariant.secondary,
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        );

      case AnswerType.audio:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: context.border),
                borderRadius: BorderRadius.circular(JetlagRadii.lg),
              ),
              child: Column(
                children: [
                  Icon(Icons.mic, size: 48, color: context.textTertiary),
                  const SizedBox(height: 8),
                  Text(
                    'Audio recording coming soon',
                    style: TextStyle(color: context.textPrimary),
                  ),
                  Text(
                    'For now, describe what you hear in text',
                    style: TextStyle(color: context.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            JetlagInput(
              label: 'Describe what you hear',
              controller: _textController,
              maxLines: 3,
            ),
          ],
        );
    }
  }

  Widget _buildVetoOption() {
    final cardsInHand = ref.watch(handWithDetailsProvider);
    final hasVetoCard = cardsInHand.any((card) => card.$2.id == 'veto');

    if (!hasVetoCard) return const SizedBox.shrink();

    return JetlagButton(
      label: 'Use Veto Card',
      icon: Icons.block,
      variant: JetlagButtonVariant.danger,
      onPressed: _isSubmitting ? null : _vetoQuestion,
    );
  }

  bool _canSubmit(Question question) {
    switch (question.answerType) {
      case AnswerType.text:
      case AnswerType.number:
      case AnswerType.audio:
        return _textController.text.trim().isNotEmpty;
      case AnswerType.boolean:
      case AnswerType.direction:
        return _selectedOption != null;
      case AnswerType.photo:
        return _photoBytes != null;
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 80);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _photoFile = image;
        _photoBytes = bytes;
      });
    }
  }

  Future<void> _submitAnswer(Question question) async {
    setState(() => _isSubmitting = true);

    try {
      String? answerText;
      String? answerPhotoUrl;

      switch (question.answerType) {
        case AnswerType.text:
        case AnswerType.number:
        case AnswerType.audio:
          answerText = _textController.text.trim();
          break;
        case AnswerType.boolean:
        case AnswerType.direction:
          answerText = _selectedOption;
          break;
        case AnswerType.photo:
          if (_photoFile != null && _photoBytes != null) {
            final service = ref.read(supabaseServiceProvider)!;
            final sessionId = ref.read(currentSessionIdProvider);
            answerPhotoUrl = await service.uploadPhoto(
              sessionId!,
              _photoFile!.path,
            );
          }
          break;
      }

      await ref.read(questionActionsProvider).answerQuestion(
            widget.sessionQuestion.id,
            answerText: answerText,
            answerPhotoUrl: answerPhotoUrl,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Answer submitted! Draw your cards.')),
        );

        await showCardDrawScreen(
          context,
          category: question.category,
          drawCount: question.category.cardsDraw,
          keepCount: question.category.cardsKeep,
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _vetoQuestion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surface,
        title: Text('Use Veto Card?', style: TextStyle(color: ctx.textPrimary)),
        content: Text(
          'This will cancel the question. The seekers will not draw cards. You will lose your Veto card.',
          style: TextStyle(color: ctx.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ctx.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Use Veto', style: TextStyle(color: ctx.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(questionActionsProvider).vetoQuestion(
            widget.sessionQuestion.id,
          );

      final cardsInHand = ref.read(handWithDetailsProvider);
      final vetoCard = cardsInHand.firstWhere((card) => card.$2.id == 'veto');
      await ref.read(cardActionsProvider).discardCard(
            vetoCard.$1.id,
            vetoCard.$2.id,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question vetoed!')),
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Color _getCategoryColor(QuestionCategory category) {
    switch (category) {
      case QuestionCategory.matching:
        return JetlagColors.matching;
      case QuestionCategory.measuring:
        return JetlagColors.measuring;
      case QuestionCategory.radar:
        return JetlagColors.radar;
      case QuestionCategory.thermometer:
        return JetlagColors.thermometer;
      case QuestionCategory.tentacles:
        return JetlagColors.tentacles;
      case QuestionCategory.photo:
        return JetlagColors.photo;
    }
  }
}
