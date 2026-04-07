# Jet Lag: Hide & Seek Companion App

A self-hosted Flutter PWA companion app for playing Jet Lag: The Game Hide & Seek (seasons 12/16 format). Served at `jetlag.ratz.fyi` with a self-hosted Supabase backend.

## Current State (Phase 2 Complete)

### Phase 1 — Core Game Loop
- Custom widget library (ratz.fyi design system with JetlagCard, JetlagButton, JetlagBadge, etc.)
- Team creation & management (self-select with balance enforcement)
- Multi-round games with role swap (hiding -> seeking -> endgame -> found)
- Question flow (ask -> countdown -> answer -> card draw) with 6 categories
- Card economy (draw N keep K, time bonuses, powerups, curses, time traps)
- Synchronized team timers (server-authoritative)
- Game over with auto winner (longest hide time)
- Light/dark mode with Plus Jakarta Sans font
- iPhone viewport optimization (safe areas, 44pt touch targets)
- Supabase wired end-to-end with Realtime
- Feature requests tab (public at `/ideas`)
- Admin dashboard at `/admin` (behind OAuth via access-manager)

### Phase 2 — Admin, Replays & Polish
- **Game Event Logging** — Every game action (phase changes, questions, cards, curses, timer, team joins) logged to `game_events` table via fire-and-forget EventLogger
- **Post-Game Summary** (`/game/:id/summary`) — Round overview, team stats, event timeline, question log, card history, key moments
- **Scrubbable Timeline Replay** (`/game/:id/replay`) — Event-sourced state reconstruction, play/pause, 1x-10x speed, scrubber bar, live event log
- **Google Maps API Usage Tracker** — `api_usage` table, cost estimation per API type, admin dashboard with progress bar vs $200 free tier, monthly projection
- **Animation Polish** — Slide+fade page transitions on all routes (250ms easeOutCubic), StaggeredItem, FlipReveal, SlideInNotification, GlowPulse utilities
- **Admin Event Log** — Filterable raw event stream with color-coded type chips, relative timestamps, last 100 events across all sessions
- **E2E Tests** — 58 Playwright tests across Mobile Chrome and Desktop Chrome

## Architecture

```
Frontend:  Flutter web PWA (static files in Docker)
Backend:   Self-hosted Supabase (PostgreSQL, GoTrue, Realtime, Storage, Kong)
Routing:   Traefik on LXC 102 -> jetlag.ratz.fyi
Auth:      Anonymous sign-in (public), /admin behind google-auth + access-check
Maps:      Google Maps JavaScript API + Places API
Font:      Plus Jakarta Sans (Google Fonts)
State:     Riverpod + Freezed models + GoRouter
```

## Project Structure

```
lib/
├── main.dart                           # App entry point
├── app/
│   ├── app.dart                        # App widget with ProviderScope
│   ├── router.dart                     # GoRouter with slide transitions
│   └── theme.dart                      # JetlagTheme (dark/light)
├── core/
│   ├── models/                         # Freezed data models
│   │   ├── game_session.dart           # Session with rounds, teams
│   │   ├── game_event.dart             # Event logging model
│   │   ├── api_usage.dart              # API usage tracking model
│   │   ├── question.dart, card.dart    # Game content models
│   │   ├── round.dart, team.dart       # Round/team models
│   │   └── models.dart                 # Barrel export
│   ├── services/
│   │   ├── supabase_service.dart       # All CRUD operations
│   │   ├── supabase_init.dart          # Client + providers
│   │   ├── realtime_service.dart       # WebSocket subscriptions
│   │   ├── api_usage_service.dart      # Maps API cost tracking
│   │   ├── places_service.dart         # Google Places API
│   │   └── services.dart               # Barrel export
│   └── providers/
│       ├── game_provider.dart          # Session state + GameActions
│       ├── game_event_provider.dart    # Event logging + streaming
│       ├── round_provider.dart         # Round state + RoundActions
│       ├── question_provider.dart      # Question flow + cooldowns
│       ├── card_provider.dart          # Card deck + CardActions
│       ├── team_provider.dart          # Team management
│       ├── timer_provider.dart         # Timer state
│       └── providers.dart              # Barrel export
├── features/
│   ├── admin/admin_screen.dart         # Admin dashboard (all sections)
│   ├── game/
│   │   ├── seeker_view.dart            # Seeker game view
│   │   ├── hider_view.dart             # Hider game view
│   │   ├── spectator_view.dart         # Spectator view
│   │   ├── game_over_screen.dart       # Winner + View Details
│   │   ├── post_game_summary.dart      # Post-game stats
│   │   ├── round_summary_screen.dart   # Between-round summary
│   │   └── game_map.dart               # Google Maps widget
│   ├── replay/
│   │   ├── replay_screen.dart          # Timeline replay UI
│   │   ├── replay_controller.dart      # Event-sourced state
│   │   └── replay_map.dart             # Replay visualization
│   ├── home/home_screen.dart           # Landing page
│   ├── lobby/                          # Join + lobby screens
│   ├── questions/                      # Question drafting + answering
│   ├── cards/                          # Card deck view
│   ├── feature_requests/               # Ideas page
│   └── settings/                       # Theme toggle
├── design/
│   ├── colors.dart                     # Design tokens
│   ├── theme.dart                      # ThemeData + extensions
│   ├── animations.dart                 # Shared animation utilities
│   └── widgets/                        # JetlagCard, JetlagButton, etc.
└── shared/                             # Legacy shared utilities

supabase/migrations/
├── 001_initial_schema.sql              # sessions, participants, questions, cards
├── 002_storage_buckets.sql             # Photo/audio storage
├── 003_teams_rounds.sql                # Teams + rounds tables
├── 004_feature_requests.sql            # Feature requests table
├── 005_nanoid_sessions.sql             # Nanoid room codes
├── 006_game_events.sql                 # Game event logging
└── 007_api_usage.sql                   # API usage tracking

e2e/
├── tests/jetlag.spec.ts                # 58 Playwright E2E tests
├── playwright.config.ts                # Mobile + Desktop Chrome
└── screenshots/                        # Visual regression screenshots
```

## Routes

| Path | Screen | Auth |
|------|--------|------|
| `/` | Home (join game) | Public |
| `/g/:code` | Lobby (join via nanoid) | Public |
| `/game/:id/seeker` | Seeker game view | Public |
| `/game/:id/hider` | Hider game view | Public |
| `/game/:id/spectator` | Spectator view | Public |
| `/game/:id/round-summary` | Between-round summary | Public |
| `/game/:id/over` | Game over screen | Public |
| `/game/:id/summary` | Post-game stats | Public |
| `/game/:id/replay` | Timeline replay | Public |
| `/game/:id/draft-question` | Question drafting | Public |
| `/ideas` | Feature requests | Public |
| `/settings` | Theme toggle | Public |
| `/create-game` | Polygon editor | Public |
| `/admin` | Admin dashboard | OAuth |

## Database Tables

| Table | Purpose |
|-------|---------|
| `sessions` | Game sessions with room codes |
| `participants` | Players with team assignments |
| `teams` | Team name, color, display order |
| `rounds` | Round state, timers, hide duration |
| `session_questions` | Asked/answered questions |
| `hider_cards` | Cards in hand / played / discarded |
| `active_curses` | Currently active curses |
| `placed_time_traps` | Time traps on the map |
| `game_areas` | Polygon boundaries for game areas |
| `feature_requests` | Public feature request submissions |
| `game_events` | Every game action for replay/stats |
| `api_usage` | Google Maps API call tracking |

## Build & Deploy

```bash
export PATH="/opt/flutter/bin:$PATH"
cd /home/claude/jetlag-hideseek

# Generate Freezed code
dart run build_runner build --delete-conflicting-outputs

# Build web
flutter build web --no-tree-shake-icons \
  --dart-define=SUPABASE_URL=https://jetlag.ratz.fyi/supabase \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNjQxNzY5MjAwLCJleHAiOjE3OTk1MzU2MDB9.hVGT3I0Nxn2dz0Tdh9HWlxu_a0HUodMXm6PSuTFGct0 \
  --dart-define=GOOGLE_PLACES_API_KEY=AIzaSyCopUFT1pPzGmrGrAR_TUWKB5M8I5n0Efc

# Deploy
cd deploy && sudo docker compose restart

# Commit and push
git add -A && git commit -m "..." && git push origin main
```

## E2E Testing

```bash
cd e2e && npx playwright test --reporter=list
```

**58 tests** across Mobile Chrome (iPhone 14 Pro viewport) and Desktop Chrome:
- Home page loading and assets
- SPA routing (all routes return 200)
- Join game flow with real Supabase data
- Full game lifecycle (create session, add players, start round, game over)
- Post-game summary with events
- Replay screen (populated and empty states)
- Event logging API
- API usage tracking API
- Page transitions
- Network performance and console errors

### Test Helpers

The test file includes helpers for E2E testing:
- `createTestGame(request)` — Creates a game area, session, and teams via Supabase REST API
- `createTestEvents(request, sessionId, roundId?)` — Inserts sample game events
- `cleanupTestGame(request, sessionId, areaId)` — Deletes all test data respecting FK constraints

### Supabase REST API

All tables are accessible via REST at `https://jetlag.ratz.fyi/supabase/rest/v1/` with the anon key as `apikey` and `Authorization: Bearer` headers.

## Design System

Premium ratz.fyi design tokens:
- **Dark**: bg=#0c0e14, surface=#151822, accent=#7b9aff, green=#5ceda0, red=#ff6b6b
- **Light**: bg=#f0f2f7, surface=#ffffff, accent=#4a6adf, green=#16a34a, red=#dc2626
- **Font**: Plus Jakarta Sans (400/500/600/700)
- **Animations**: 250ms easeOutCubic transitions, staggered list items, spring physics

## License

Personal/educational use. Jet Lag: The Game is a trademark of Wendover Productions.
