import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import 'question_detail.dart';

class QuestionBrowser extends ConsumerStatefulWidget {
  const QuestionBrowser({super.key});

  @override
  ConsumerState<QuestionBrowser> createState() => _QuestionBrowserState();
}

class _QuestionBrowserState extends ConsumerState<QuestionBrowser>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  QuestionCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedCategory = QuestionCategory.values[_tabController.index];
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final testMode = ref.watch(testModeProvider);

    return Column(
      children: [
        // Test mode toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: testMode ? Colors.orange.shade100 : null,
          child: Row(
            children: [
              Icon(
                testMode ? Icons.science : Icons.science_outlined,
                color: testMode ? Colors.orange : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Mode',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      testMode
                          ? 'Questions won\'t count or draw cards'
                          : 'Try questions hypothetically',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: testMode,
                onChanged: (value) {
                  ref.read(testModeProvider.notifier).state = value;
                },
                activeColor: Colors.orange,
              ),
            ],
          ),
        ),

        // Category tabs
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: QuestionCategory.values.map((category) {
            final cooldownRemaining =
                ref.watch(categoryRemainingCooldownProvider(category));
            final isOnCooldown = cooldownRemaining != null;

            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category.displayName),
                  if (isOnCooldown && !testMode) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.timer,
                      size: 14,
                      color: Colors.orange,
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),

        // Category info
        _buildCategoryInfo(),

        // Questions list
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: QuestionCategory.values.map((category) {
              return _QuestionList(
                category: category,
                testMode: testMode,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryInfo() {
    final category = _selectedCategory ?? QuestionCategory.matching;
    final cooldownRemaining =
        ref.watch(categoryRemainingCooldownProvider(category));
    final testMode = ref.watch(testModeProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      color: _getCategoryColor(category).withOpacity(0.1),
      child: Row(
        children: [
          // Card reward
          _InfoChip(
            icon: Icons.style,
            label: category.cardRewardText,
          ),
          const SizedBox(width: 12),
          // Response time
          _InfoChip(
            icon: Icons.timer,
            label: '${category.defaultResponseTimeMinutes} min',
          ),
          const Spacer(),
          // Cooldown
          if (cooldownRemaining != null && !testMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Cooldown: ${_formatDuration(cooldownRemaining)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _QuestionList extends ConsumerWidget {
  final QuestionCategory category;
  final bool testMode;

  const _QuestionList({
    required this.category,
    required this.testMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(questionsByCategoryProvider(category));
    final isOnCooldown = ref.watch(isCategoryOnCooldownProvider(category));
    final canAsk = testMode || !isOnCooldown;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index];
        return _QuestionCard(
          question: question,
          canAsk: canAsk,
          testMode: testMode,
        );
      },
    );
  }
}

class _QuestionCard extends ConsumerWidget {
  final Question question;
  final bool canAsk;
  final bool testMode;

  const _QuestionCard({
    required this.question,
    required this.canAsk,
    required this.testMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showQuestionDetail(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      question.text,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _AnswerTypeChip(answerType: question.answerType),
                  const Spacer(),
                  if (question.requiresLocation)
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuestionDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => QuestionDetail(
        question: question,
        canAsk: canAsk,
        testMode: testMode,
      ),
    );
  }
}

class _AnswerTypeChip extends StatelessWidget {
  final AnswerType answerType;

  const _AnswerTypeChip({required this.answerType});

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (answerType) {
      AnswerType.text => (Icons.text_fields, 'Text'),
      AnswerType.photo => (Icons.photo_camera, 'Photo'),
      AnswerType.audio => (Icons.mic, 'Audio'),
      AnswerType.boolean => (Icons.check_circle, 'Yes/No'),
      AnswerType.number => (Icons.numbers, 'Number'),
      AnswerType.direction => (Icons.explore, 'Direction'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
