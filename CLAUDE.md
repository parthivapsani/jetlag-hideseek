# Jet Lag: Hide & Seek — Agent Guide

## What This Is

Flutter web PWA at `jetlag.ratz.fyi` for playing Jet Lag: The Game Hide & Seek. Self-hosted Supabase backend. Phase 1 (core game loop) and Phase 2 (admin, replays, polish) are complete.

## Quick Reference

### Build & Deploy
```bash
export PATH="/opt/flutter/bin:$PATH"
cd /home/claude/jetlag-hideseek
dart run build_runner build --delete-conflicting-outputs
flutter build web --no-tree-shake-icons \
  --dart-define=SUPABASE_URL=https://jetlag.ratz.fyi/supabase \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNjQxNzY5MjAwLCJleHAiOjE3OTk1MzU2MDB9.hVGT3I0Nxn2dz0Tdh9HWlxu_a0HUodMXm6PSuTFGct0 \
  --dart-define=GOOGLE_PLACES_API_KEY=AIzaSyCopUFT1pPzGmrGrAR_TUWKB5M8I5n0Efc
cd deploy && sudo docker compose restart
```

### Run E2E Tests
```bash
cd /home/claude/jetlag-hideseek/e2e && npx playwright test --reporter=list
```

58 tests, Mobile + Desktop Chrome. All should pass.

### Apply Migrations
```bash
sudo docker exec -i supabase-db psql -U postgres -d postgres < supabase/migrations/NNN_name.sql
```

## Supabase REST API

Base: `https://jetlag.ratz.fyi/supabase/rest/v1`

Headers for all requests:
```
apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNjQxNzY5MjAwLCJleHAiOjE3OTk1MzU2MDB9.hVGT3I0Nxn2dz0Tdh9HWlxu_a0HUodMXm6PSuTFGct0
Authorization: Bearer <same key>
Content-Type: application/json
Prefer: return=representation
```

## E2E Testing Guide

### Browser Testing at jetlag.ratz.fyi

The app is a Flutter web PWA. It renders on a `<canvas>` element — standard DOM selectors won't find text/buttons. Use visual verification (screenshots) or Supabase API to verify state.

### Key Screens to Test

| URL | What to verify |
|-----|----------------|
| `jetlag.ratz.fyi` | Home loads, "JET LAG" title visible, Join Game card, Ideas/Settings/Admin links |
| `jetlag.ratz.fyi/ideas` | Feature request form visible, existing requests listed |
| `jetlag.ratz.fyi/settings` | Theme toggle visible |
| `jetlag.ratz.fyi/admin` | Redirects to OAuth (access-manager) |
| `jetlag.ratz.fyi/g/<roomCode>` | Join flow or lobby (depending on game state) |
| `jetlag.ratz.fyi/game/<id>/seeker` | Map with game area polygon, status bar, timer |
| `jetlag.ratz.fyi/game/<id>/hider` | Map with hiding zone, incoming question banner |
| `jetlag.ratz.fyi/game/<id>/spectator` | Read-only game view |
| `jetlag.ratz.fyi/game/<id>/over` | Winner banner, team stats, "View Details" button |
| `jetlag.ratz.fyi/game/<id>/summary` | Game overview, team stats, event timeline |
| `jetlag.ratz.fyi/game/<id>/replay` | Replay with scrubber, play/pause, speed controls |

### Creating Test Data via API

To test screens that need game data, create it via the REST API:

**1. Create a game area:**
```bash
curl -X POST "$BASE/game_areas" -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" -H "Prefer: return=representation" \
  -d '{"name":"Test Area","inclusion_polygons":[{"id":"test","points":[{"lat":40.75,"lng":-73.99},{"lat":40.76,"lng":-73.99},{"lat":40.76,"lng":-73.98},{"lat":40.75,"lng":-73.98}],"isExclusion":false}],"exclusion_polygons":[],"center_lat":40.755,"center_lng":-73.985,"default_zoom":14,"created_by":"test"}'
```

**2. Create a session:**
```bash
curl -X POST "$BASE/sessions" -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" -H "Prefer: return=representation" \
  -d '{"room_code":"testcode123","status":"waiting","game_area_id":"<area_id>","hiding_period_seconds":3600,"zone_radius_meters":804.672,"created_by":"test"}'
```

**3. Create teams:**
```bash
curl -X POST "$BASE/teams" -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" -H "Prefer: return=representation" \
  -d '[{"session_id":"<session_id>","name":"Team Alpha","color":"green","display_order":0},{"session_id":"<session_id>","name":"Team Beta","color":"red","display_order":1}]'
```

**4. Add participants:**
```bash
curl -X POST "$BASE/participants" -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" -H "Prefer: return=representation" \
  -d '{"session_id":"<session_id>","display_name":"Alice","role":"seeker","device_token":"test-alice","is_connected":true,"team_id":"<team_alpha_id>"}'
```

**5. Create a round:**
```bash
curl -X POST "$BASE/rounds" -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" -H "Prefer: return=representation" \
  -d '{"session_id":"<session_id>","round_number":1,"hider_team_id":"<team_beta_id>","seeker_team_id":"<team_alpha_id>","status":"seeking","seeking_started_at":"2026-04-06T12:00:00Z"}'
```

**6. Log game events:**
```bash
curl -X POST "$BASE/game_events" -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" -H "Prefer: return=representation" \
  -d '[
    {"session_id":"<id>","round_id":"<id>","event_type":"round_started","payload":{"roundNumber":1}},
    {"session_id":"<id>","round_id":"<id>","event_type":"phase_change","payload":{"phase":"hiding"}},
    {"session_id":"<id>","round_id":"<id>","event_type":"phase_change","payload":{"phase":"seeking"}},
    {"session_id":"<id>","round_id":"<id>","event_type":"question_asked","payload":{"questionId":"match_1","category":"matching"}},
    {"session_id":"<id>","round_id":"<id>","event_type":"question_answered","payload":{"answerText":"Yes"}},
    {"session_id":"<id>","round_id":"<id>","event_type":"card_drawn","payload":{"cardId":"time_5"}},
    {"session_id":"<id>","round_id":"<id>","event_type":"round_ended","payload":{"hideDurationSeconds":1800}},
    {"session_id":"<id>","event_type":"game_ended","payload":{"winnerId":null}}
  ]'
```

**7. End a game (to test summary/replay):**
```bash
curl -X PATCH "$BASE/sessions?id=eq.<session_id>" -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"status":"ended","winning_team_id":"<team_id>","ended_at":"2026-04-06T13:00:00Z"}'

curl -X PATCH "$BASE/rounds?session_id=eq.<session_id>&round_number=eq.1" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"status":"found","found_at":"2026-04-06T13:00:00Z","hide_duration_seconds":1800}'
```

**8. Clean up test data:**
```bash
curl -X DELETE "$BASE/game_events?session_id=eq.<id>" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
curl -X DELETE "$BASE/participants?session_id=eq.<id>" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
curl -X DELETE "$BASE/rounds?session_id=eq.<id>" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
curl -X DELETE "$BASE/teams?session_id=eq.<id>" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
curl -X DELETE "$BASE/sessions?id=eq.<id>" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
curl -X DELETE "$BASE/game_areas?id=eq.<area_id>" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
```

### Valid Event Types

The `game_events` table has a CHECK constraint. Valid types:
`phase_change`, `question_asked`, `question_answered`, `card_drawn`, `card_played`, `curse_activated`, `location_update`, `timer_pause`, `timer_resume`, `player_joined`, `player_left`, `round_started`, `round_ended`, `game_started`, `game_ended`

### Session Statuses

`waiting`, `hiding`, `seeking`, `paused`, `ended`

### Round Statuses

`waiting`, `hiding`, `seeking`, `endgame`, `found`

## Flutter Canvas Rendering Note

Flutter web renders to a `<canvas>` — you cannot use DOM selectors to find buttons or text. To verify UI:
1. Take screenshots and visually inspect them
2. Check the page loaded (content length > 1000 bytes, contains "flutter")
3. Verify game state via the Supabase API (the UI reads from the same tables)

## Conventions

- Push to `main` continuously — user wants versions to revert to
- Use `usePathUrlStrategy()` in main.dart (already set)
- Anonymous auth only, no accounts. Identity via localStorage per game.
- Polygon data uses both `lat`/`lng` and `latitude`/`longitude` — parser handles both
- All Freezed models need `dart run build_runner build --delete-conflicting-outputs` after changes
- Design system: JetlagCard, JetlagButton, JetlagBadge, JetlagTimer, JetlagStatusBar, JetlagInput, JetlagSkeleton, JetlagBottomSheet
- Theme extensions: `context.bg`, `context.surface`, `context.accent`, `context.green`, `context.red`, etc.
