import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/supabase_service.dart';

class AnswerInterface extends ConsumerStatefulWidget {
  final SessionQuestion sessionQuestion;

  const AnswerInterface({super.key, required this.sessionQuestion});

  @override
  ConsumerState<AnswerInterface> createState() => _AnswerInterfaceState();
}

class _AnswerInterfaceState extends ConsumerState<AnswerInterface> {
  final _textController = TextEditingController();
  String? _selectedOption;
  File? _photoFile;
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
        coinCost: 0,
        cardsDrawn: 0,
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
              color: isUrgent ? Colors.red.shade100 : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer,
                  color: isUrgent ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Time Remaining: ${_formatDuration(remainingTime)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isUrgent ? Colors.red : Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Question
          Text(
            question.text,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            widget.sessionQuestion.category.displayName,
            style: TextStyle(
              color: _getCategoryColor(widget.sessionQuestion.category),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Rules
          if (question.rules != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(question.rules!),
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
          ElevatedButton(
            onPressed: _canSubmit(question) && !_isSubmitting
                ? () => _submitAnswer(question)
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Submit Answer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
        return TextField(
          controller: _textController,
          decoration: const InputDecoration(
            labelText: 'Your Answer',
            border: OutlineInputBorder(),
            hintText: 'Type your answer here...',
          ),
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
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedOption = selected ? option : null;
                });
              },
            );
          }).toList(),
        );

      case AnswerType.number:
        return TextField(
          controller: _textController,
          decoration: const InputDecoration(
            labelText: 'Your Answer',
            border: OutlineInputBorder(),
            hintText: 'Enter a number...',
          ),
          keyboardType: TextInputType.number,
        );

      case AnswerType.photo:
        return Column(
          children: [
            if (_photoFile != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _photoFile!,
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
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          ],
        );

      case AnswerType.audio:
        return Column(
          children: [
            // TODO: Implement audio recording
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.mic, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Audio recording coming soon'),
                  Text(
                    'For now, describe what you hear in text',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Describe what you hear',
                border: OutlineInputBorder(),
              ),
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

    return OutlinedButton.icon(
      onPressed: _isSubmitting ? null : _vetoQuestion,
      icon: const Icon(Icons.block, color: Colors.purple),
      label: const Text('Use Veto Card'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.purple,
        side: const BorderSide(color: Colors.purple),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
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
        return _photoFile != null;
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 80);
    if (image != null) {
      setState(() {
        _photoFile = File(image.path);
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
          if (_photoFile != null) {
            final service = ref.read(supabaseServiceProvider);
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
          const SnackBar(content: Text('Answer submitted!')),
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
      builder: (context) => AlertDialog(
        title: const Text('Use Veto Card?'),
        content: const Text(
          'This will cancel the question. The seekers will not draw cards. You will lose your Veto card.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use Veto'),
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

      // Also discard the veto card
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
        return Colors.blue;
      case QuestionCategory.measuring:
        return Colors.purple;
      case QuestionCategory.radar:
        return Colors.green;
      case QuestionCategory.thermometer:
        return Colors.orange;
      case QuestionCategory.tentacles:
        return Colors.teal;
      case QuestionCategory.photo:
        return Colors.pink;
    }
  }
}
