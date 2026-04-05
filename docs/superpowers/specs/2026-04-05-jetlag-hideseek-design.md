# Jet Lag: Hide & Seek — Design Spec

## Overview

A self-hosted Flutter PWA companion app for playing Jet Lag: The Game Hide & Seek (seasons 12/16 format). Served at `jetlag.ratz.fyi` with a self-hosted Supabase backend. Teams of 3+ play multi-round games where they alternate hiding and seeking, with the team that hides longest winning.

## Architecture

### Deployment
- **Frontend:** Flutter web PWA served as static files on the homeserver
- **Backend:** Self-hosted Supabase in Docker (PostgreSQL, GoTrue auth, Realtime, Storage, Kong API gateway)
- **Routing:** Traefik on LXC 102 routes `jetlag.ratz.fyi` → app port on Proxmox host. Supabase is reverse-proxied under `/supabase/` with WebSocket upgrade support for Realtime.
- **Auth:** Public — anonymous sign-in with device token + display name (same pattern as billsplit). Room code is access control. Admin dashboard at `/admin` behind google-auth + access-check middleware.
- **HTTPS:** Handled by Traefik + Let's Encrypt via Cloudflare DNS challenge (existing infra).

### Tech Stack
- **Frontend:** Flutter 3.x, Riverpod state management, GoRouter, Freezed models, Google Maps Flutter (web)
- **Backend:** Supabase (PostgreSQL + GoTrue + Realtime + Storage)
- **Maps:** Google Maps JavaScript API + Places API (legacy)
- **Font:** Plus Jakarta Sans (Google Fonts) — matches ratz.fyi design system
- **Design System:** Custom widget library implementing the ratz.fyi design tokens

## Delivery Phases

### Phase 1 — Core Game Loop (ship first)
- Custom widget library (ratz.fyi design system)
- Team creation & management (self-select with balance enforcement)
- Multi-round games with role swap
- Question flow (ask → countdown → answer → card draw)
- Synchronized team timers
- Game over → auto winner (longest hide time)
- Light / dark mode (Plus Jakarta Sans)
- iPhone viewport optimization
- Web compatibility fixes (google_maps_flutter_web, dart:io removal, etc.)
- Supabase wired end-to-end
- Feature requests tab (public)
- Traefik route + access-manager sites list entry

### Phase 2 — Admin, Replays & Polish
- Admin dashboard (`/admin`, behind auth)
- Create / stop / archive games
- Previous games in reverse chronological order
- Post-game summary view
- Full timeline replay (scrubbable)
- Server-side event logging (game_events table)
- Google Maps API usage tracker
- Animation polish & micro-interactions

## Game Model

### Multi-Round Sessions

A **session** represents a full game played under one room code. A session contains:
- Two **teams** (self-selected, must be within 1 player of each other to start)
- Multiple **rounds** (typically 2 — each team hides once)
- The winner is the team that hid longest across all rounds
- Admin can override the winner

### Game Flow

```
Home → Join (room code + name) → Lobby (team selection)
  → Round 1: Team A hides, Team B seeks
    → hiding phase → seeking phase → endgame → found
  → Round Summary (show hide time, stats, role swap)
  → Round 2: Team B hides, Team A seeks
    → hiding phase → seeking phase → endgame → found
  → Game Over (compare hide times → declare winner)
```

### Round Lifecycle

```
waiting → hiding → seeking → endgame → found
```

- **waiting:** Teams assigned roles, admin starts the round
- **hiding:** Hider team has X minutes to hide (configurable: 30m / 1h / 2.5h / 4h)
- **seeking:** Timer starts for seekers. Seeker team asks questions, hider team answers.
- **endgame:** Seekers are in the hiding zone, hider cannot move, questions are exact (no squish).
- **found:** Round over. Record hide time.

### Question Flow

1. Seeker team collectively decides on a question (any team member can submit)
2. Submitting starts a response countdown for the hider team
3. If hiders don't respond in time: no card reward, seeking timer pauses until hiders answer (incentivizes timely responses without punishing seekers)
4. After answering, hider team draws cards per category rules
5. Categories have 30-minute cooldowns

### Question Categories (Season 12/16 Rules)

| Category | Draw | Keep | Format |
|----------|------|------|--------|
| Matching | 3 | 1 | "Is your X the same as our X?" |
| Measuring | 3 | 1 | "Are you closer to X than we are?" |
| Radar | 2 | 1 | "Are you within X distance of us?" |
| Thermometer | 2 | 1 | "We moved X, warmer or colder?" |
| Tentacles | 4 | 2 | "Of all X near us, which is closest to you?" |
| Photo | 1 | 1 | "Send us a picture of X" |

### Card Economy

Pure card-based (no coins). Card types:
- **Time Bonus** — adds time to hiding period
- **Powerup** — special abilities
- **Curse** — restricts seekers (express route only, long shot, runner, museum)
- **Time Trap** — placed at stations, triggers when seekers arrive

Card mechanics:
- **Draw without replacement** — cards come from a draw pile, never re-drawn until the pile is empty, then discard pile reshuffles back in
- **Draw N, keep K** — after hiders answer a question, they see N cards face-up, pick K to keep, rest go to discard (e.g. Matching: draw 3, keep 1)
- **Play anytime** — hiders can play cards from their hand at any point during the round (curses, time bonuses, powerups, time traps)
- **Round-scoped** — each round starts with a fresh shuffled deck. Cards do not carry between rounds.

### Squish Boundary

Since the hider can move within their hiding zone (configurable: 0-1 mile), questions have uncertainty. The squish boundary visualizes the uncertainty zone on the map. Disabled in endgame (hider cannot move, questions are exact).

## Schema Changes

### New Tables

**teams**
- `id` UUID PK
- `session_id` UUID FK → sessions
- `name` VARCHAR (e.g. "Team Alpha")
- `color` VARCHAR (e.g. "green", "red")
- `display_order` INTEGER

**rounds**
- `id` UUID PK
- `session_id` UUID FK → sessions
- `round_number` INTEGER
- `hider_team_id` UUID FK → teams
- `seeker_team_id` UUID FK → teams
- `status` VARCHAR (waiting / hiding / seeking / endgame / found)
- `hiding_started_at` TIMESTAMPTZ
- `seeking_started_at` TIMESTAMPTZ
- `timer_paused_at` TIMESTAMPTZ
- `paused_time_remaining_seconds` INTEGER
- `found_at` TIMESTAMPTZ
- `hide_duration_seconds` INTEGER (computed on found)
- `created_at` TIMESTAMPTZ

**game_events** (for replay & logging)
- `id` UUID PK
- `session_id` UUID FK → sessions
- `round_id` UUID FK → rounds (nullable for session-level events)
- `event_type` VARCHAR (phase_change / question_asked / question_answered / card_drawn / card_played / curse_activated / location_update / timer_pause / timer_resume / player_joined / player_left)
- `payload` JSONB
- `created_at` TIMESTAMPTZ
- Indexed: (session_id, round_id, created_at)

**feature_requests**
- `id` UUID PK
- `title` VARCHAR
- `description` TEXT
- `status` VARCHAR (open / in_progress / done)
- `submitter_name` VARCHAR
- `created_at` TIMESTAMPTZ
- `updated_at` TIMESTAMPTZ

### Modified Tables

**participants**
- Add `team_id` UUID FK → teams
- Remove `role` field (role is derived from team assignment per round)

**session_questions**
- Add `round_id` UUID FK → rounds

**hider_cards**
- Add `round_id` UUID FK → rounds

**active_curses**
- Add `round_id` UUID FK → rounds

**sessions**
- Add `winning_team_id` UUID FK → teams (nullable)
- Add `winner_override` BOOLEAN DEFAULT false
- Add `total_rounds` INTEGER DEFAULT 2
- Move round-specific timer fields to `rounds` table

## UI Design

### Design System — ratz.fyi Widget Library

Custom Flutter widget library (~15 components) implementing the ratz.fyi design tokens:

**Colors:** Exact tokens from the shared design system.
- Dark: bg=#0c0e14, surface=#151822, surface2=#1e2231, surface3=#272c3d, accent=#7b9aff, green=#5ceda0, red=#ff6b6b, purple=#b39dff, orange=#ffb347
- Light: bg=#f0f2f7, surface=#ffffff, surface2=#f5f6fa, surface3=#ebedf3, accent=#4a6adf, green=#16a34a, red=#dc2626, purple=#7c3aed, orange=#d97706

**Typography:** Plus Jakarta Sans (400/500/600/700). Gradient headings, uppercase labels with letter-spacing, tabular-nums for timers/stats.

**Components:**
- `JetlagCard` — top-edge glow, surface bg, hover lift
- `JetlagButton` — primary/secondary/danger variants, hover translateY(-1px) + accent shadow
- `JetlagBadge` — inner glow, pulse dot for live indicators (green/red/orange/blue/purple)
- `JetlagModal` — blurred backdrop, scale entrance
- `JetlagBottomSheet` — draggable (collapsed/half/full), spring physics, pill handle
- `JetlagTimer` — tabular-nums display with warning color transitions
- `JetlagInput` — glow ring on focus
- `JetlagSkeleton` — shimmer loading with accent glow sweep
- `JetlagTabs` — pill container with sliding indicator
- `JetlagStatusBar` — role-colored header (green=hiding, red=seeking, gray=spectating)

**Animations:**
- Page transitions: shared axis (horizontal slide)
- List items: staggered cardIn (50ms delay, slide up + fade)
- State changes: AnimatedSwitcher, 200ms ease-out
- Bottom sheet: spring physics drag, snap positions
- Card draw: flip reveal with glow pulse
- Notifications: slide down from top for incoming questions

**Theme toggle:** System / Light / Dark pill selector, persisted in localStorage.

### View Switching — Hybrid (Map + Bottom Sheet)

Map is always the hero, always visible. Bottom tab bar has Map / Questions / Cards / Team.

- **Map tab:** Full-screen map with FAB for asking questions
- **Questions tab:** Opens as bottom sheet overlay on the map (half-screen, draggable to full). Can see the map while browsing questions — important since questions often reference map locations.
- **Cards tab:** Opens as bottom sheet overlay on the map (same as questions)
- **Team tab:** Opens as full-screen page (no map needed)

Bottom sheet has three snap positions: collapsed (just handle visible), half (map peeks above), full (covers map).

### Screen Inventory

**Public screens:**
- Home — gradient branding, Join Game button, How to Play, Ideas (feature requests), Settings
- Join — 6-character room code input (individual boxes with accent glow cursor), display name
- Lobby — room code display + copy, two team columns, tap name to switch teams, player count, Start Round button (disabled until teams balanced)
- Game (Seeker) — role-colored status bar (red) with timer, team indicator, map with teammate pins, FAB to ask question, bottom sheet for Questions/Cards
- Game (Hider) — role-colored status bar (green) with timer, incoming question banner with countdown, bottom sheet for Answer/Cards
- Game (Spectator) — gray status bar, full game view, live event feed overlay
- Round Summary — hide time, stats, role swap visualization, "Start Round N" button with target to beat
- Game Over — winner declaration (longest hide time), stats comparison, round-by-round breakdown
- Feature Requests — submit form + list with status badges (open/in progress/done)
- Settings — theme toggle, display name, about

**Admin screens (behind auth):**
- Dashboard — active games (live badge, spectate/stop), previous games reverse-chronological (replay/stats)
- New Game — polygon editor → settings → create → room code
- Game Controls — pause/resume, force end round, override winner, add/remove player, adjust timer, archive
- API Usage — progress bar vs $200 free tier, breakdown by API type
- Analytics — game stats, player stats
- Event Log — raw event stream, filterable

### iPhone Optimization

- Safe area insets respected (notch, home indicator)
- Touch targets minimum 44x44pt
- Bottom sheet respects home indicator area
- Map controls positioned for one-handed use
- FAB positioned for right-thumb reach
- Room code input uses large tap targets, auto-advances between characters
- Haptic feedback on key interactions (question submitted, card drawn, round over)

## Game Area

Existing polygon editor supports:
- **Inclusion polygons** — draw the play area boundary
- **Exclusion polygons** — cut out zones within the boundary
- **Nominatim search** — auto-generate boundary from OpenStreetMap data
- **Manual vertex editing** — add/move/delete/insert vertices
- **Saved areas** — reuse game areas across sessions

## Feature Requests

Same pattern as billsplit and travel-monitor:
- Public page accessible from home screen "Ideas" button
- Submit: title + description + optional name
- List: reverse chronological with status badges
- Status: open → in_progress → done (admin changes from /admin dashboard)
- Stored in `feature_requests` Supabase table

## Access Manager Integration

Add `jetlag.ratz.fyi` to the access-manager sites list at `sites.ratz.fyi` with:
- `/admin` and `/api/admin/*` paths behind google-auth + access-check
- All other paths public (no auth)

## Web Compatibility Fixes Required

| Issue | Files Affected | Fix |
|-------|---------------|-----|
| `google_maps_flutter` mobile-only imports | game_area.dart, game_map.dart, polygon_editor_screen.dart, question_drafting_screen.dart | Conditional imports or switch to web-compatible API |
| `dart:io` File class | photo_service.dart, answer_interface.dart | Use Uint8List / XFile / web blob approach |
| `path_provider` unavailable on web | photo_service.dart | Use in-memory or IndexedDB storage |
| `permission_handler` not needed on web | location_service.dart | Conditional import, browser handles permissions |
| Stray import in timer_provider.dart line 248 | timer_provider.dart | Remove stray import |
| Missing CardActions methods | card_draw_screen.dart | Add drawRandomCard(), keepCard(), discardDrawnCard() |
| Duplicate provider definitions | supabase_init.dart, auth_provider.dart, game_provider.dart | Consolidate to single source in supabase_init.dart |
| Remove dead dependency | pubspec.yaml | Remove purchases_flutter (RevenueCat) |

## Google Maps API Usage Tracker

Client-side counter tracking:
- Map load events
- Places API calls
- Geocoding API calls

Stored in Supabase table, displayed on admin dashboard as:
- Progress bar against $200/month free tier
- Breakdown by API type with estimated cost
- Rate projection ("at current rate: ~$X/mo")

## Event Logging & Replay

Every game action writes to the `game_events` table via Supabase Realtime triggers. Events are timestamped and indexed by session + round + timestamp.

**Post-game summary** (Phase 2): Stats page with question log, card history, key moments, movement paths.

**Timeline replay** (Phase 2): Scrubbable timeline that reconstructs map state, question flow, and card plays at any point. Built by replaying events in order up to the scrub position.
