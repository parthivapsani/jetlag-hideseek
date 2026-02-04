import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screen.dart';
import '../features/home/home_screen.dart';
import '../features/game_area/polygon_editor_screen.dart';
import '../features/lobby/lobby_screen.dart';
import '../features/lobby/join_game_screen.dart';
import '../features/game/seeker_view.dart';
import '../features/game/hider_view.dart';
import '../features/game/spectator_view.dart';
import '../features/game/game_over_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/questions/question_drafting_screen.dart';
import '../core/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/auth';

      // Allow access to home without auth (anonymous play supported)
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/create-game',
        name: 'create-game',
        builder: (context, state) => const PolygonEditorScreen(),
      ),
      GoRoute(
        path: '/join',
        name: 'join',
        builder: (context, state) => const JoinGameScreen(),
      ),
      GoRoute(
        path: '/lobby/:sessionId',
        name: 'lobby',
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
        path: '/game/:sessionId/over',
        name: 'game-over',
        builder: (context, state) => GameOverScreen(
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
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
