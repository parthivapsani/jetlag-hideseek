import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }

  // Common empty states
  factory EmptyState.noQuestions({VoidCallback? onAskFirst}) {
    return EmptyState(
      icon: Icons.question_answer_outlined,
      title: 'No questions yet',
      subtitle: 'Questions asked by seekers will appear here',
      action: onAskFirst != null
          ? ElevatedButton.icon(
              onPressed: onAskFirst,
              icon: const Icon(Icons.add),
              label: const Text('Ask First Question'),
            )
          : null,
    );
  }

  factory EmptyState.noCards() {
    return const EmptyState(
      icon: Icons.style_outlined,
      title: 'No cards in hand',
      subtitle: 'You\'ll draw cards when seekers ask questions',
    );
  }

  factory EmptyState.noPlayers() {
    return const EmptyState(
      icon: Icons.people_outline,
      title: 'Waiting for players',
      subtitle: 'Share the room code to invite others',
    );
  }

  factory EmptyState.noGameAreas({VoidCallback? onCreate}) {
    return EmptyState(
      icon: Icons.map_outlined,
      title: 'No saved areas',
      subtitle: 'Create a game area to get started',
      action: onCreate != null
          ? ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Area'),
            )
          : null,
    );
  }

  factory EmptyState.error({
    required String message,
    VoidCallback? onRetry,
  }) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      subtitle: message,
      action: onRetry != null
          ? OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            )
          : null,
    );
  }

  factory EmptyState.loading({String? message}) {
    return EmptyState(
      icon: Icons.hourglass_empty,
      title: message ?? 'Loading...',
    );
  }
}

class ErrorCard extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  const ErrorCard({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  if (message != null)
                    Text(
                      message!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (onRetry != null)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: onRetry,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
          ],
        ),
      ),
    );
  }
}
