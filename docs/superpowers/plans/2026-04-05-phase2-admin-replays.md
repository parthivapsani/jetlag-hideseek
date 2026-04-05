# Phase 2: Admin, Replays & Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add post-game summaries, scrubbable timeline replays, server-side event logging, Google Maps API usage tracking, and animation polish to the Jet Lag: Hide & Seek PWA.

**Spec:** `docs/superpowers/specs/2026-04-05-jetlag-hideseek-design.md`

**What's already done (from Phase 1 + admin work):**
- Admin dashboard at `/admin` with create/stop/view games, feature request management, quick-create from location name
- Previous games in reverse chronological order on admin page
- Core game loop fully functional (teams, rounds, questions, cards, timers)
- Design system widgets (JetlagCard, JetlagButton, JetlagBadge, JetlagTimer, JetlagStatusBar, JetlagBottomSheet, etc.)
- Playwright E2E tests at `e2e/`

**Build & Deploy:**
```bash
export PATH="/opt/flutter/bin:$PATH"
cd /home/claude/jetlag-hideseek
flutter build web --no-tree-shake-icons \
  --dart-define=SUPABASE_URL=https://jetlag.ratz.fyi/supabase \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNjQxNzY5MjAwLCJleHAiOjE3OTk1MzU2MDB9.hVGT3I0Nxn2dz0Tdh9HWlxu_a0HUodMXm6PSuTFGct0 \
  --dart-define=GOOGLE_PLACES_API_KEY=AIzaSyCopUFT1pPzGmrGrAR_TUWKB5M8I5n0Efc
cd deploy && sudo docker compose restart
git add -A && git commit -m "..." && git push origin main
```

**Important notes:**
- Push to main continuously — user wants versions to revert to
- Use `usePathUrlStrategy()` in main.dart (already set, don't remove)
- Polygon data uses both `lat`/`lng` and `latitude`/`longitude` — parser normalizes both
- Anonymous auth only, no accounts. Identity via localStorage per game.
- Run Playwright tests after changes: `cd e2e && npx playwright test --reporter=list`

---

## Task 1: Game Events Table & Logging

The `game_events` table stores every game action for replay. The schema is defined in the spec.

**Files:**
- Create: `supabase/migrations/006_game_events.sql`
- Create: `lib/core/models/game_event.dart`
- Modify: `lib/core/services/supabase_service.dart`
- Create: `lib/core/providers/game_event_provider.dart`

- [ ] **Step 1: Create migration**

Create `supabase/migrations/006_game_events.sql`:

```sql
CREATE TABLE game_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    round_id UUID REFERENCES rounds(id),
    event_type VARCHAR(50) NOT NULL,
    payload JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT valid_event_type CHECK (event_type IN (
        'phase_change', 'question_asked', 'question_answered',
        'card_drawn', 'card_played', 'curse_activated',
        'location_update', 'timer_pause', 'timer_resume',
        'player_joined', 'player_left', 'round_started', 'round_ended',
        'game_started', 'game_ended'
    ))
);

CREATE INDEX idx_game_events_session ON game_events(session_id, created_at);
CREATE INDEX idx_game_events_round ON game_events(round_id, created_at);
CREATE INDEX idx_game_events_type ON game_events(event_type);

ALTER TABLE game_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view game events" ON game_events FOR SELECT USING (true);
CREATE POLICY "Anyone can create game events" ON game_events FOR INSERT WITH CHECK (true);

ALTER PUBLICATION supabase_realtime ADD TABLE game_events;
```

Apply: `sudo docker exec -i supabase-db psql -U postgres -d postgres < supabase/migrations/006_game_events.sql`

- [ ] **Step 2: Create GameEvent Freezed model**

```dart
@freezed
class GameEvent with _$GameEvent {
  const factory GameEvent({
    required String id,
    required String sessionId,
    String? roundId,
    required String eventType,
    @Default({}) Map<String, dynamic> payload,
    DateTime? createdAt,
  }) = _GameEvent;

  factory GameEvent.fromJson(Map<String, dynamic> json) => _$GameEventFromJson(json);
}
```

- [ ] **Step 3: Add CRUD to SupabaseService**

Methods: `logEvent(sessionId, roundId, eventType, payload)`, `getSessionEvents(sessionId)`, `getRoundEvents(roundId)`

- [ ] **Step 4: Create event provider**

Provider that streams events for the current session via Supabase Realtime.

- [ ] **Step 5: Wire event logging into existing actions**

Add `logEvent()` calls to:
- RoundActions (startRound, startHiding, startSeeking, enterEndgame, markFound)
- QuestionProvider (askQuestion, answerQuestion)
- CardProvider (drawCards, keepCard, playCard)
- GameActions (pauseGame, resumeGame, endGame)
- TeamActions (switchTeam) — log as player_joined/player_left from team perspective

- [ ] **Step 6: Run build_runner, commit, build, deploy, push**

---

## Task 2: Post-Game Summary View

A detailed stats page shown after a game ends, accessible from game over screen and admin dashboard.

**Files:**
- Create: `lib/features/game/post_game_summary.dart`
- Modify: `lib/features/game/game_over_screen.dart` (add "View Details" button)
- Modify: `lib/features/admin/admin_screen.dart` (add "Stats" button on previous games)
- Modify: `lib/app/router.dart`

- [ ] **Step 1: Create post-game summary screen**

Shows:
- **Timeline**: chronological list of key events (phase changes, questions, card plays)
- **Question Log**: all questions asked, answers, categories, response times
- **Card History**: cards drawn, kept, played, with timing
- **Team Stats**: questions per team, cards per team, hide times
- **Key Moments**: auto-detected highlights (longest gap between questions, fastest answer, most cards drawn in one round)

Use `gameEventsProvider` to load all events for the session, then derive the stats client-side.

- [ ] **Step 2: Add routes and navigation**

Route: `/game/:sessionId/summary`
Link from game over screen "View Details" button and admin "Stats" button.

- [ ] **Step 3: Commit, build, deploy, push**

---

## Task 3: Scrubbable Timeline Replay

Reconstruct the game state at any point in time by replaying events up to a scrub position.

**Files:**
- Create: `lib/features/replay/replay_screen.dart`
- Create: `lib/features/replay/replay_controller.dart`
- Create: `lib/features/replay/replay_map.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/features/admin/admin_screen.dart` (add "Replay" button)

- [ ] **Step 1: Create replay controller**

A Riverpod notifier that:
- Loads all events for a session
- Has a `scrubPosition` (DateTime)
- Reconstructs game state at any position by replaying events in order up to that time
- Supports play/pause/speed controls (1x, 2x, 5x, 10x)
- Exposes: current phase, active questions, played cards, team positions, timer state

- [ ] **Step 2: Create replay map**

Google Maps widget that shows:
- Game area polygon
- Player positions at the current scrub time (from location_update events)
- Question markers (where questions were asked)
- Card play markers
- Animated movements when playing

- [ ] **Step 3: Create replay screen**

Layout:
- Map fills most of the screen
- Bottom scrubber bar (like a video player timeline)
- Event markers on the timeline (color-coded by type)
- Play/pause button and speed selector
- Current time display
- Side panel or bottom sheet with event log at current position

- [ ] **Step 4: Add routes and navigation**

Route: `/game/:sessionId/replay`
Link from admin "Replay" button and post-game summary.

- [ ] **Step 5: Commit, build, deploy, push**

---

## Task 4: Google Maps API Usage Tracker

Track and display Maps API usage against the $200/month free tier.

**Files:**
- Create: `supabase/migrations/007_api_usage.sql`
- Create: `lib/core/models/api_usage.dart`
- Create: `lib/core/services/api_usage_service.dart`
- Modify: `lib/features/admin/admin_screen.dart`

- [ ] **Step 1: Create API usage table**

```sql
CREATE TABLE api_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    api_type VARCHAR(50) NOT NULL, -- 'map_load', 'places', 'geocoding'
    session_id UUID REFERENCES sessions(id),
    estimated_cost_cents INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_api_usage_created ON api_usage(created_at);
CREATE INDEX idx_api_usage_type ON api_usage(api_type);
```

- [ ] **Step 2: Create client-side tracking service**

Intercept Google Maps API calls and log them to the table. Track:
- Map load events (every time a map widget initializes)
- Places API calls (autocomplete, details)
- Geocoding calls

- [ ] **Step 3: Add usage dashboard to admin**

Show on admin page:
- Progress bar: current month usage vs $200 free tier
- Breakdown by API type with estimated costs
- Rate projection: "at current rate: ~$X/mo"
- Monthly chart if enough data

- [ ] **Step 4: Commit, build, deploy, push**

---

## Task 5: Animation Polish & Micro-interactions

Polish the UI with the animations specified in the design spec.

**Files:**
- Modify: Various screen files
- Create: `lib/design/animations.dart` (shared animation utilities)

- [ ] **Step 1: Page transitions**

Add shared axis horizontal slide transitions to GoRouter:

```dart
GoRoute(
  path: '/...',
  pageBuilder: (context, state) => CustomTransitionPage(
    child: ...,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween(begin: Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        ),
        child: child,
      );
    },
  ),
),
```

- [ ] **Step 2: List item stagger animations**

Add staggered cardIn animation (50ms delay between items, slide up + fade) to:
- Feature requests list
- Question browser
- Card deck view
- Lobby player lists

- [ ] **Step 3: Card draw flip animation**

When drawing cards, show a flip reveal with glow pulse:
- Card starts face-down
- Flips with a 3D rotation
- Glow pulse on reveal
- Staggered if multiple cards drawn

- [ ] **Step 4: State change transitions**

Add AnimatedSwitcher (200ms ease-out) to:
- Phase changes (hiding → seeking → endgame)
- Timer warning state (normal → red)
- Badge status changes

- [ ] **Step 5: Notification slide-in**

Incoming question notifications slide down from top of map:
- SlideTransition from Offset(0, -1) to Offset.zero
- Auto-dismiss after response or timeout

- [ ] **Step 6: Commit, build, deploy, push, run Playwright tests**

---

## Task 6: Admin Event Log

Raw event stream viewer on admin dashboard.

**Files:**
- Modify: `lib/features/admin/admin_screen.dart`

- [ ] **Step 1: Add Event Log tab/section to admin**

Shows:
- Filterable by session, event type, time range
- Real-time streaming of new events
- Each event shows: timestamp, type, round number, payload summary
- Color-coded by event type

- [ ] **Step 2: Commit, build, deploy, push**

---

## Task 7: Final E2E Tests & Polish

- [ ] **Step 1: Add Playwright tests for new features**

Test: post-game summary loads, replay page loads, event logging works, API usage tracking.

- [ ] **Step 2: Run full test suite**

```bash
cd e2e && npx playwright test --reporter=list
```

- [ ] **Step 3: Visual review of all screenshots**

Check every screenshot for rendering issues.

- [ ] **Step 4: Fix any issues, final commit and push**
