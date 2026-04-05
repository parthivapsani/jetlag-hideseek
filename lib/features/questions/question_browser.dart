import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/jetlag_badge.dart';
import '../../design/widgets/jetlag_card.dart';
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
    _tabController = TabController(length: 6, vsync: this);
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
          color: testMode ? context.orange.withValues(alpha: 0.12) : null,
          child: Row(
            children: [
              Icon(
                testMode ? Icons.science : Icons.science_outlined,
                color: testMode ? context.orange : context.textTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      testMode
                          ? 'Questions won\'t count or draw cards'
                          : 'Try questions hypothetically',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
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
                activeColor: context.orange,
              ),
            ],
          ),
        ),

        // Category tabs
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: context.accent,
          unselectedLabelColor: context.textTertiary,
          indicatorColor: context.accent,
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
                    Icon(Icons.timer, size: 14, color: context.orange),
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
      color: _getCategoryColor(category).withValues(alpha: 0.08),
      child: Row(
        children: [
          _InfoChip(
            icon: Icons.style,
            label: category.cardRewardText,
          ),
          const SizedBox(width: 12),
          _InfoChip(
            icon: Icons.timer,
            label: '${category.defaultResponseTimeMinutes} min',
          ),
          const Spacer(),
          if (cooldownRemaining != null && !testMode)
            JetlagBadge(
              label: 'Cooldown: ${_formatDuration(cooldownRemaining)}',
              color: JetlagBadgeColor.orange,
              showPulse: true,
            ),
        ],
      ),
    );
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
        Icon(icon, size: 16, color: context.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.textTertiary,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: JetlagCard(
        onTap: () => _showQuestionDetail(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    question.text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: context.textTertiary, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _AnswerTypeChip(answerType: question.answerType),
                const Spacer(),
                if (question.requiresLocation)
                  Icon(Icons.location_on, size: 16, color: context.textTertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuestionDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
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
        color: context.surface2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}
