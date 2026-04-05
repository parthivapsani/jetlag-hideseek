import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/jetlag_button.dart';
import '../../design/widgets/jetlag_input.dart';

/// Legacy join screen - redirects to /g/:code via the home screen's join field.
/// Kept for any old deep links that might reference /join without a code.
class JoinGameScreen extends ConsumerWidget {
  const JoinGameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Redirect to home — the join functionality is now on the home screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('/');
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
