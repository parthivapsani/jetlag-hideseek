import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/feature_request.dart';
import '../../core/providers/feature_request_provider.dart';
import '../../design/widgets/widgets.dart';
import '../../design/theme.dart';

class FeatureRequestsScreen extends ConsumerStatefulWidget {
  const FeatureRequestsScreen({super.key});

  @override
  ConsumerState<FeatureRequestsScreen> createState() => _FeatureRequestsScreenState();
}

class _FeatureRequestsScreenState extends ConsumerState<FeatureRequestsScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final actions = ref.read(featureRequestActionsProvider);
      await actions.submit(
        title: title,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        submitterName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
      );

      _titleController.clear();
      _descriptionController.clear();
      _nameController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Idea submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(featureRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Ideas'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Submit form
          JetlagCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Submit an Idea',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                JetlagInput(
                  label: 'Title',
                  hint: 'What would you like to see?',
                  controller: _titleController,
                ),
                const SizedBox(height: 12),
                JetlagInput(
                  label: 'Description',
                  hint: 'Any additional details? (optional)',
                  controller: _descriptionController,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                JetlagInput(
                  label: 'Your Name',
                  hint: 'Optional',
                  controller: _nameController,
                ),
                const SizedBox(height: 16),
                Center(
                  child: JetlagButton(
                    label: 'Submit Idea',
                    icon: Icons.lightbulb_outline,
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Feature requests list
          requestsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Failed to load ideas: $error',
                  style: TextStyle(color: context.red),
                ),
              ),
            ),
            data: (requests) {
              if (requests.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No ideas yet. Be the first!',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Ideas',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  ...requests.map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FeatureRequestCard(request: request),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureRequestCard extends StatelessWidget {
  final FeatureRequest request;

  const _FeatureRequestCard({required this.request});

  JetlagBadgeColor _badgeColor(FeatureRequestStatus status) {
    switch (status) {
      case FeatureRequestStatus.open:
        return JetlagBadgeColor.blue;
      case FeatureRequestStatus.inProgress:
        return JetlagBadgeColor.orange;
      case FeatureRequestStatus.done:
        return JetlagBadgeColor.green;
    }
  }

  String _statusLabel(FeatureRequestStatus status) {
    switch (status) {
      case FeatureRequestStatus.open:
        return 'Open';
      case FeatureRequestStatus.inProgress:
        return 'In Progress';
      case FeatureRequestStatus.done:
        return 'Done';
    }
  }

  String _relativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 365) return '${diff.inDays ~/ 365}y ago';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    return JetlagCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 8),
              JetlagBadge(
                label: _statusLabel(request.status),
                color: _badgeColor(request.status),
              ),
            ],
          ),
          if (request.description != null && request.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            [
              if (request.submitterName != null) request.submitterName!,
              _relativeTime(request.createdAt),
            ].where((s) => s.isNotEmpty).join(' \u2022 '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
