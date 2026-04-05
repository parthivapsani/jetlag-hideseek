import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/game_area/polygon_editor_screen.dart';
import '../features/lobby/lobby_screen.dart';
import '../features/game/seeker_view.dart';
import '../features/game/hider_view.dart';
import '../features/game/spectator_view.dart';
import '../features/game/game_over_screen.dart';
import '../features/game/round_summary_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/questions/question_drafting_screen.dart';
import '../features/feature_requests/feature_requests_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/game/post_game_summary.dart';
import '../features/replay/replay_screen.dart';

/// Shared horizontal slide + fade transition for all routes.
CustomTransitionPage<void> _slidePage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/create-game',
        name: 'create-game',
        pageBuilder: (context, state) =>
            _slidePage(const PolygonEditorScreen(), state),
      ),
      GoRoute(
        path: '/g/:code',
        name: 'lobby',
        pageBuilder: (context, state) => _slidePage(
          LobbyScreen(sessionCode: state.pathParameters['code']!),
          state,
        ),
      ),
      GoRoute(
        path: '/join/:code',
        redirect: (context, state) => '/g/${state.pathParameters['code']}',
      ),
      GoRoute(
        path: '/lobby/:sessionId',
        name: 'lobby-legacy',
        pageBuilder: (context, state) => _slidePage(
          LobbyScreen(sessionId: state.pathParameters['sessionId']!),
          state,
        ),
      ),
      GoRoute(
        path: '/game/:sessionId/seeker',
        name: 'seeker',
        pageBuilder: (context, state) => _slidePage(
          SeekerView(sessionId: state.pathParameters['sessionId']!),
          state,
        ),
      ),
      GoRoute(
        path: '/game/:sessionId/hider',
        name: 'hider',
        pageBuilder: (context, state) => _slidePage(
          HiderView(sessionId: state.pathParameters['sessionId']!),
          state,
        ),
      ),
      GoRoute(
        path: '/game/:sessionId/spectator',
        name: 'spectator',
        pageBuilder: (context, state) => _slidePage(
          SpectatorView(sessionId: state.pathParameters['sessionId']!),
          state,
        ),
      ),
      GoRoute(
        path: '/game/:sessionId/round-summary',
        name: 'round-summary',
        pageBuilder: (context, state) => _slidePage(
          RoundSummaryScreen(sessionId: state.pathParameters['sessionId']!),
          state,
        ),
      ),
      GoRoute(
        path: '/game/:sessionId/over',
        name: 'game-over',
        pageBuilder: (context, state) => _slidePage(
          GameOverScreen(sessionId: state.pathParameters['sessionId']!),
          state,
        ),
      ),
      GoRoute(
        path: '/game/:sessionId/summary',
        name: 'game-summary',
        pageBuilder: (context, state) => _slidePage(
          PostGameSummary(sessionId: state.pathParameters['sessionId']!),
          state,
        ),
      ),
      GoRoute(
        path: '/game/:sessionId/replay',
        name: 'game-replay',
        pageBuilder: (context, state) => _slidePage(
          ReplayScreen(sessionId: state.pathParameters['sessionId']!),
          state,
        ),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) =>
            _slidePage(const SettingsScreen(), state),
      ),
      GoRoute(
        path: '/game/:sessionId/draft-question',
        name: 'draft-question',
        pageBuilder: (context, state) => _slidePage(
          QuestionDraftingScreen(
              sessionId: state.pathParameters['sessionId']!),
          state,
        ),
      ),
      GoRoute(
        path: '/ideas',
        name: 'ideas',
        pageBuilder: (context, state) =>
            _slidePage(const FeatureRequestsScreen(), state),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        pageBuilder: (context, state) =>
            _slidePage(const AdminScreen(), state),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
