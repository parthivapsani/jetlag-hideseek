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
        builder: (context, state) => const PolygonEditorScreen(),
      ),
      // Game lobby via nanoid
      GoRoute(
        path: '/g/:code',
        name: 'lobby',
        builder: (context, state) => LobbyScreen(
          sessionCode: state.pathParameters['code']!,
        ),
      ),
      // Backwards compat: /join/:code redirects to /g/:code
      GoRoute(
        path: '/join/:code',
        redirect: (context, state) => '/g/${state.pathParameters['code']}',
      ),
      // Legacy lobby route by session ID
      GoRoute(
        path: '/lobby/:sessionId',
        name: 'lobby-legacy',
        builder: (context, state) => LobbyScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/game/:sessionId/seeker',
        name: 'seeker',
        builder: (context, state) => SeekerView(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/game/:sessionId/hider',
        name: 'hider',
        builder: (context, state) => HiderView(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/game/:sessionId/spectator',
        name: 'spectator',
        builder: (context, state) => SpectatorView(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/game/:sessionId/round-summary',
        name: 'round-summary',
        builder: (context, state) => RoundSummaryScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/game/:sessionId/over',
        name: 'game-over',
        builder: (context, state) => GameOverScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/game/:sessionId/summary',
        name: 'game-summary',
        builder: (context, state) => PostGameSummary(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/game/:sessionId/draft-question',
        name: 'draft-question',
        builder: (context, state) => QuestionDraftingScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/ideas',
        name: 'ideas',
        builder: (context, state) => const FeatureRequestsScreen(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
