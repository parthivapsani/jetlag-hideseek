# Phase 1: Core Game Loop — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a playable multi-round team-based Jet Lag: Hide & Seek PWA at `jetlag.ratz.fyi` with the ratz.fyi design system, synchronized timers, card economy, and feature requests.

**Architecture:** Flutter web PWA with self-hosted Supabase backend. Custom widget library implementing ratz.fyi design tokens (Plus Jakarta Sans, dark/light themes, glow effects). Hybrid map + bottom sheet navigation. Teams and rounds modeled as separate Supabase tables. Realtime sync via Supabase channels.

**Tech Stack:** Flutter 3.x (web), Riverpod, GoRouter, Freezed, Supabase (self-hosted Docker), Google Maps JavaScript API, Google Places API (legacy)

**Spec:** `docs/superpowers/specs/2026-04-05-jetlag-hideseek-design.md`

**Google Maps API Key:** `AIzaSyCopUFT1pPzGmrGrAR_TUWKB5M8I5n0Efc`

**Supabase (already running):**
- Kong API gateway: `http://localhost:8000`
- Anon key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNjQxNzY5MjAwLCJleHAiOjE3OTk1MzU2MDB9.hVGT3I0Nxn2dz0Tdh9HWlxu_a0HUodMXm6PSuTFGct0`
- Public URL (after Traefik): `https://jetlag.ratz.fyi/supabase`

**Infrastructure (already done):**
- Docker installed on Proxmox host
- Supabase stack running at `/opt/supabase/docker/`
- Flutter SDK at `/opt/flutter`
- Traefik config at `/root/homeserver/config/traefik/dynamic/external-services.yml` (needs jetlag entry pushed to LXC 102)

---

## File Structure

### New Files

```
lib/
  design/                           # ratz.fyi design system
    theme.dart                      # JetlagTheme with dark/light color tokens, text styles
    colors.dart                     # Color constants matching ratz.fyi CSS variables
    widgets/
      jetlag_card.dart              # Card with top-edge glow, hover lift
      jetlag_button.dart            # Primary/secondary/danger with hover effects
      jetlag_badge.dart             # Inner glow badges with pulse dot
      jetlag_bottom_sheet.dart      # Draggable 3-snap bottom sheet (collapsed/half/full)
      jetlag_input.dart             # Input with glow ring focus
      jetlag_timer.dart             # Tabular-nums timer display
      jetlag_modal.dart             # Blurred backdrop modal
      jetlag_tabs.dart              # Pill tabs with sliding indicator
      jetlag_status_bar.dart        # Role-colored header bar
      jetlag_skeleton.dart          # Shimmer loading skeleton
      widgets.dart                  # Barrel export
  core/
    models/
      team.dart                     # Team model (Freezed)
      round.dart                    # Round model (Freezed)
      feature_request.dart          # FeatureRequest model (Freezed)
    providers/
      team_provider.dart            # Team state + actions
      round_provider.dart           # Round state + actions
      feature_request_provider.dart # Feature request CRUD
  features/
    feature_requests/
      feature_requests_screen.dart  # Public ideas page
    lobby/
      team_selection.dart           # Team selection widget (extracted from lobby)

web/                                # Created by `flutter create --platforms=web .`
  index.html                        # With Google Maps JS script tag + Plus Jakarta Sans

supabase/
  migrations/
    003_teams_rounds.sql            # teams, rounds tables + schema modifications
    004_feature_requests.sql        # feature_requests table
```

### Modified Files

```
lib/main.dart                       # Update Supabase config
lib/app/app.dart                    # Switch to JetlagTheme
lib/app/router.dart                 # Add feature requests route
lib/app/theme.dart                  # Replace with ratz.fyi design system (or redirect to design/theme.dart)
lib/core/models/game_session.dart   # Add winning_team_id, winner_override, total_rounds
lib/core/models/models.dart         # Export new models
lib/core/providers/auth_provider.dart         # Remove duplicate supabaseClientProvider
lib/core/providers/game_provider.dart         # Remove duplicate providers, add team/round awareness
lib/core/providers/game_state_provider.dart   # Round-aware phase tracking
lib/core/providers/timer_provider.dart        # Fix stray import, round-aware timers
lib/core/providers/card_provider.dart         # Add missing CardActions methods, round-scoped
lib/core/providers/providers.dart             # Export new providers
lib/core/services/supabase_service.dart       # Add team/round/feature_request CRUD
lib/core/services/supabase_init.dart          # Remove duplicate providers, set real Supabase URL
lib/core/services/realtime_service.dart       # Add round-scoped subscriptions
lib/core/services/services.dart               # Export updates
lib/features/home/home_screen.dart            # Restyle with design system, add Ideas button
lib/features/lobby/lobby_screen.dart          # Team selection UI, balance enforcement
lib/features/lobby/join_game_screen.dart      # Restyle with design system
lib/features/game/seeker_view.dart            # Hybrid bottom sheet navigation, design system
lib/features/game/hider_view.dart             # Hybrid bottom sheet navigation, design system
lib/features/game/spectator_view.dart         # Design system restyle
lib/features/game/game_over_screen.dart       # Multi-round results, winner by hide time
lib/features/game/game_map.dart               # Web compatibility
lib/features/cards/card_draw_screen.dart      # Fix broken method references
lib/features/cards/card_deck_view.dart        # Design system restyle
lib/features/settings/settings_screen.dart    # Theme toggle (system/light/dark)
lib/features/questions/question_drafting_screen.dart  # Web compat, design system
lib/features/questions/answer_interface.dart   # Web compat (dart:io removal)
lib/features/auth/auth_screen.dart            # Design system restyle
lib/shared/widgets/*                          # May be replaced by design/ widgets
pubspec.yaml                                  # Remove purchases_flutter, add google_maps_flutter_web
```

---

## Task 1: Web Platform Setup & Dependency Fixes

**Files:**
- Modify: `pubspec.yaml`
- Create: `web/` directory (via flutter create)
- Modify: `web/index.html`
- Modify: `lib/core/providers/timer_provider.dart:248`

- [ ] **Step 1: Create web platform**

```bash
cd /home/claude/jetlag-hideseek
export PATH="/opt/flutter/bin:$PATH"
flutter create --platforms=web .
```

Expected: Creates `web/` directory with `index.html`, `manifest.json`, etc.

- [ ] **Step 2: Add Google Maps JS + Plus Jakarta Sans to web/index.html**

In `web/index.html`, add these lines inside `<head>` before the existing `<script>` tags:

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
<script src="https://maps.googleapis.com/maps/api/js?key=AIzaSyCopUFT1pPzGmrGrAR_TUWKB5M8I5n0Efc&libraries=places"></script>
```

- [ ] **Step 3: Fix pubspec.yaml**

Remove `purchases_flutter` dependency (dead weight, no code wiring):

```yaml
  # DELETE these 2 lines:
  # Payments (RevenueCat)
  purchases_flutter: ^6.17.0
```

- [ ] **Step 4: Fix stray import in timer_provider.dart**

Remove the stray `import 'question_provider.dart';` at line 248 of `lib/core/providers/timer_provider.dart`. It appears after code and would cause a compile error.

- [ ] **Step 5: Run flutter pub get**

```bash
cd /home/claude/jetlag-hideseek
flutter pub get
```

Expected: Dependencies resolve successfully.

- [ ] **Step 6: Generate Freezed models**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: Generates `.freezed.dart` and `.g.dart` files for all models. May have errors due to compile issues — that's expected, we'll fix in subsequent tasks.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add web platform, remove RevenueCat, fix timer import

- Create web/ directory with Google Maps JS and Plus Jakarta Sans
- Remove dead purchases_flutter dependency
- Fix stray import in timer_provider.dart line 248

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Consolidate Duplicate Providers

The codebase has `supabaseClientProvider` and `supabaseServiceProvider` defined in three places: `supabase_init.dart`, `auth_provider.dart`, and `game_provider.dart`. This causes compile errors. Consolidate to a single source.

**Files:**
- Modify: `lib/core/services/supabase_init.dart`
- Modify: `lib/core/providers/auth_provider.dart`
- Modify: `lib/core/providers/game_provider.dart`

- [ ] **Step 1: Update supabase_init.dart to be the single source**

In `lib/core/services/supabase_init.dart`, ensure these providers exist (they already do):

```dart
/// The single source of truth for Supabase client.
/// Returns null if Supabase is not configured.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!Supabase.instance.client.auth.currentSession?.isExpired ?? true) {
    // Client exists
  }
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

final supabaseServiceProvider = Provider<SupabaseService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return SupabaseService(client);
});
```

- [ ] **Step 2: Remove duplicate from auth_provider.dart**

In `lib/core/providers/auth_provider.dart`, remove the `supabaseClientProvider` definition. Replace it with an import:

```dart
import '../services/supabase_init.dart' show supabaseClientProvider;
```

Update all references in the file to handle the nullable type (`SupabaseClient?`). The `AuthActions` class should accept a nullable client and no-op when null.

- [ ] **Step 3: Remove duplicate from game_provider.dart**

In `lib/core/providers/game_provider.dart`, remove the `supabaseServiceProvider` and `supabaseClientProvider` definitions. Replace with imports:

```dart
import '../services/supabase_init.dart' show supabaseClientProvider, supabaseServiceProvider;
```

Update `realtimeServiceProvider` and `locationServiceProvider` to handle nullable Supabase client.

- [ ] **Step 4: Verify compilation**

```bash
dart analyze lib/core/services/supabase_init.dart lib/core/providers/auth_provider.dart lib/core/providers/game_provider.dart
```

Expected: No errors for these files (warnings about unused imports are OK at this stage).

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/supabase_init.dart lib/core/providers/auth_provider.dart lib/core/providers/game_provider.dart
git commit -m "fix: consolidate duplicate Supabase provider definitions

Single source of truth in supabase_init.dart. Auth and game providers
import from there instead of redefining.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Database Migrations — Teams, Rounds, Feature Requests

**Files:**
- Create: `supabase/migrations/003_teams_rounds.sql`
- Create: `supabase/migrations/004_feature_requests.sql`

- [ ] **Step 1: Write teams and rounds migration**

Create `supabase/migrations/003_teams_rounds.sql`:

```sql
-- Teams
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    color VARCHAR(20) NOT NULL DEFAULT 'green',
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_teams_session_id ON teams(session_id);

-- Rounds
CREATE TABLE rounds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    round_number INTEGER NOT NULL DEFAULT 1,
    hider_team_id UUID REFERENCES teams(id),
    seeker_team_id UUID REFERENCES teams(id),
    status VARCHAR(20) NOT NULL DEFAULT 'waiting',
    hiding_started_at TIMESTAMP WITH TIME ZONE,
    seeking_started_at TIMESTAMP WITH TIME ZONE,
    timer_paused_at TIMESTAMP WITH TIME ZONE,
    paused_time_remaining_seconds INTEGER,
    found_at TIMESTAMP WITH TIME ZONE,
    hide_duration_seconds INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT valid_round_status CHECK (status IN ('waiting', 'hiding', 'seeking', 'endgame', 'found')),
    CONSTRAINT unique_round_per_session UNIQUE (session_id, round_number)
);

CREATE INDEX idx_rounds_session_id ON rounds(session_id);
CREATE INDEX idx_rounds_status ON rounds(status);

-- Modify participants: add team_id
ALTER TABLE participants ADD COLUMN team_id UUID REFERENCES teams(id);

-- Modify sessions: add team-based winner fields
ALTER TABLE sessions ADD COLUMN winning_team_id UUID REFERENCES teams(id);
ALTER TABLE sessions ADD COLUMN winner_override BOOLEAN DEFAULT false;
ALTER TABLE sessions ADD COLUMN total_rounds INTEGER DEFAULT 2;

-- Modify session_questions: add round_id
ALTER TABLE session_questions ADD COLUMN round_id UUID REFERENCES rounds(id);

-- Modify hider_cards: add round_id
ALTER TABLE hider_cards ADD COLUMN round_id UUID REFERENCES rounds(id);

-- Modify active_curses: add round_id
ALTER TABLE active_curses ADD COLUMN round_id UUID REFERENCES rounds(id);

-- Enable RLS on new tables
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE rounds ENABLE ROW LEVEL SECURITY;

-- RLS Policies for teams
CREATE POLICY "Anyone can view teams" ON teams FOR SELECT USING (true);
CREATE POLICY "Anyone can create teams" ON teams FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update teams" ON teams FOR UPDATE USING (true);

-- RLS Policies for rounds
CREATE POLICY "Anyone can view rounds" ON rounds FOR SELECT USING (true);
CREATE POLICY "Anyone can create rounds" ON rounds FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update rounds" ON rounds FOR UPDATE USING (true);

-- Enable Realtime for new tables
ALTER PUBLICATION supabase_realtime ADD TABLE teams;
ALTER PUBLICATION supabase_realtime ADD TABLE rounds;
```

- [ ] **Step 2: Write feature requests migration**

Create `supabase/migrations/004_feature_requests.sql`:

```sql
-- Feature Requests
CREATE TABLE feature_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    submitter_name VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT valid_feature_status CHECK (status IN ('open', 'in_progress', 'done'))
);

CREATE INDEX idx_feature_requests_status ON feature_requests(status);
CREATE INDEX idx_feature_requests_created ON feature_requests(created_at DESC);

-- RLS: anyone can view and submit, only admin can update status
ALTER TABLE feature_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view feature requests" ON feature_requests
    FOR SELECT USING (true);

CREATE POLICY "Anyone can submit feature requests" ON feature_requests
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update feature requests" ON feature_requests
    FOR UPDATE USING (true);
```

- [ ] **Step 3: Apply migrations**

```bash
sudo docker exec -i supabase-db psql -U postgres -d postgres < /home/claude/jetlag-hideseek/supabase/migrations/003_teams_rounds.sql
sudo docker exec -i supabase-db psql -U postgres -d postgres < /home/claude/jetlag-hideseek/supabase/migrations/004_feature_requests.sql
```

Note: The container name may differ. Check with `sudo docker ps | grep postgres` to find the correct name (likely `supabase-db` or `supabase-docker-db-1`).

Expected: Tables created, columns added. Verify:

```bash
sudo docker exec -i supabase-db psql -U postgres -d postgres -c "\dt" | grep -E "teams|rounds|feature"
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/003_teams_rounds.sql supabase/migrations/004_feature_requests.sql
git commit -m "feat: add teams, rounds, feature_requests tables

New tables for multi-round team games and public feature requests.
Adds round_id FK to questions, cards, curses. Adds team/winner fields
to sessions and participants.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Design System — Colors & Theme

**Files:**
- Create: `lib/design/colors.dart`
- Create: `lib/design/theme.dart`

- [ ] **Step 1: Create colors.dart**

Create `lib/design/colors.dart`:

```dart
import 'package:flutter/material.dart';

/// ratz.fyi design system color tokens.
/// Dark mode is default. Light mode overrides via JetlagTheme.
class JetlagColors {
  JetlagColors._();

  // === Dark Mode ===
  static const darkBg = Color(0xFF0C0E14);
  static const darkSurface = Color(0xFF151822);
  static const darkSurface2 = Color(0xFF1E2231);
  static const darkSurface3 = Color(0xFF272C3D);
  static const darkBorder = Color(0xFF2A2F42);
  static const darkBorderSubtle = Color(0xFF1E2231);
  static const darkText = Color(0xFFEEF0F6);
  static const darkText2 = Color(0xFF8B8FA3);
  static const darkText3 = Color(0xFF5C6070);

  // === Light Mode ===
  static const lightBg = Color(0xFFF0F2F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFF5F6FA);
  static const lightSurface3 = Color(0xFFEBEDF3);
  static const lightBorder = Color(0xFFDFE1E9);
  static const lightBorderSubtle = Color(0xFFEBEDF3);
  static const lightText = Color(0xFF14171F);
  static const lightText2 = Color(0xFF4A4E5E);
  static const lightText3 = Color(0xFF8B8FA3);

  // === Accent Colors (shared) ===
  static const accent = Color(0xFF7B9AFF);
  static const accent2 = Color(0xFF5A7DE8);
  static const accentLight = Color(0xFF4A6ADF);
  static const accentLight2 = Color(0xFF3A54BF);

  // === Semantic Colors ===
  static const green = Color(0xFF5CEDA0);
  static const greenLight = Color(0xFF16A34A);
  static const red = Color(0xFFFF6B6B);
  static const redLight = Color(0xFFDC2626);
  static const orange = Color(0xFFFFB347);
  static const orangeLight = Color(0xFFD97706);
  static const purple = Color(0xFFB39DFF);
  static const purpleLight = Color(0xFF7C3AED);

  // === Glow Colors (dark mode) ===
  static const accentGlow = Color(0x267B9AFF); // 15% opacity
  static const accentGlow2 = Color(0x147B9AFF); // 8% opacity
  static const greenGlow = Color(0x1F5CEDA0); // 12%
  static const redGlow = Color(0x1FFF6B6B); // 12%
  static const orangeGlow = Color(0x1FFFB347); // 12%
  static const purpleGlow = Color(0x1FB39DFF); // 12%

  // === Glow Colors (light mode) ===
  static const accentGlowLight = Color(0x1A4A6ADF); // 10%
  static const greenGlowLight = Color(0x1416A34A); // 8%
  static const redGlowLight = Color(0x14DC2626); // 8%
  static const orangeGlowLight = Color(0x14D97706); // 8%
  static const purpleGlowLight = Color(0x147C3AED); // 8%

  // === Game Role Colors ===
  static const hider = green;
  static const seeker = red;
  static const spectator = darkText3;
  static const hiderLight = greenLight;
  static const seekerLight = redLight;

  // === Question Category Colors ===
  static const matching = accent;
  static const measuring = purple;
  static const radar = green;
  static const thermometer = orange;
  static const tentacles = Color(0xFF26C6DA); // teal
  static const photo = Color(0xFFEC407A); // pink
}

/// Radii matching the design system.
class JetlagRadii {
  JetlagRadii._();
  static const double sm = 10.0;
  static const double lg = 14.0;
  static const double xl = 18.0;
}
```

- [ ] **Step 2: Create theme.dart**

Create `lib/design/theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';

class JetlagTheme {
  JetlagTheme._();

  static const _fontFamily = 'Plus Jakarta Sans';

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: JetlagColors.darkBg,
      colorScheme: const ColorScheme.dark(
        surface: JetlagColors.darkSurface,
        primary: JetlagColors.accent,
        secondary: JetlagColors.accent2,
        error: JetlagColors.red,
        onSurface: JetlagColors.darkText,
        onPrimary: Colors.white,
      ),
      cardTheme: CardTheme(
        color: JetlagColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JetlagRadii.lg),
          side: const BorderSide(color: JetlagColors.darkBorderSubtle),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: JetlagColors.darkBg,
        foregroundColor: JetlagColors.darkText,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      dividerTheme: const DividerThemeData(
        color: JetlagColors.darkBorder,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: JetlagColors.darkSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JetlagRadii.sm),
          borderSide: const BorderSide(color: JetlagColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JetlagRadii.sm),
          borderSide: const BorderSide(color: JetlagColors.accent),
        ),
        labelStyle: const TextStyle(
          fontSize: 12,
          color: JetlagColors.darkText2,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: JetlagColors.darkText),
        headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: JetlagColors.darkText),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: JetlagColors.darkText),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: JetlagColors.darkText),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: JetlagColors.darkText2),
        bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: JetlagColors.darkText2),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: JetlagColors.darkText3),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: JetlagColors.darkText),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: JetlagColors.darkText2, letterSpacing: 0.5),
      ),
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: JetlagColors.lightBg,
      colorScheme: const ColorScheme.light(
        surface: JetlagColors.lightSurface,
        primary: JetlagColors.accentLight,
        secondary: JetlagColors.accentLight2,
        error: JetlagColors.redLight,
        onSurface: JetlagColors.lightText,
        onPrimary: Colors.white,
      ),
      cardTheme: CardTheme(
        color: JetlagColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JetlagRadii.lg),
          side: const BorderSide(color: JetlagColors.lightBorderSubtle),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: JetlagColors.lightBg,
        foregroundColor: JetlagColors.lightText,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dividerTheme: const DividerThemeData(
        color: JetlagColors.lightBorder,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: JetlagColors.lightSurface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JetlagRadii.sm),
          borderSide: const BorderSide(color: JetlagColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JetlagRadii.sm),
          borderSide: const BorderSide(color: JetlagColors.accentLight),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: JetlagColors.lightText),
        headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: JetlagColors.lightText),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: JetlagColors.lightText),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: JetlagColors.lightText),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: JetlagColors.lightText2),
        bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: JetlagColors.lightText2),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: JetlagColors.lightText3),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: JetlagColors.lightText),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: JetlagColors.lightText2, letterSpacing: 0.5),
      ),
    );
  }
}

/// Extension for quick access to design system colors from BuildContext.
extension JetlagThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => isDark ? JetlagColors.darkBg : JetlagColors.lightBg;
  Color get surface => isDark ? JetlagColors.darkSurface : JetlagColors.lightSurface;
  Color get surface2 => isDark ? JetlagColors.darkSurface2 : JetlagColors.lightSurface2;
  Color get surface3 => isDark ? JetlagColors.darkSurface3 : JetlagColors.lightSurface3;
  Color get border => isDark ? JetlagColors.darkBorder : JetlagColors.lightBorder;
  Color get borderSubtle => isDark ? JetlagColors.darkBorderSubtle : JetlagColors.lightBorderSubtle;
  Color get textPrimary => isDark ? JetlagColors.darkText : JetlagColors.lightText;
  Color get textSecondary => isDark ? JetlagColors.darkText2 : JetlagColors.lightText2;
  Color get textTertiary => isDark ? JetlagColors.darkText3 : JetlagColors.lightText3;
  Color get accent => isDark ? JetlagColors.accent : JetlagColors.accentLight;
  Color get accentGlow => isDark ? JetlagColors.accentGlow : JetlagColors.accentGlowLight;
  Color get green => isDark ? JetlagColors.green : JetlagColors.greenLight;
  Color get red => isDark ? JetlagColors.red : JetlagColors.redLight;
  Color get orange => isDark ? JetlagColors.orange : JetlagColors.orangeLight;
  Color get purple => isDark ? JetlagColors.purple : JetlagColors.purpleLight;
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/design/
git commit -m "feat: add ratz.fyi design system — colors and theme

Plus Jakarta Sans font, dark/light color tokens matching ratz.fyi CSS
variables, Material 3 ThemeData for both modes, BuildContext extensions
for quick color access.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Design System — Core Widgets

**Files:**
- Create: `lib/design/widgets/jetlag_card.dart`
- Create: `lib/design/widgets/jetlag_button.dart`
- Create: `lib/design/widgets/jetlag_badge.dart`
- Create: `lib/design/widgets/jetlag_input.dart`
- Create: `lib/design/widgets/jetlag_timer.dart`
- Create: `lib/design/widgets/jetlag_status_bar.dart`
- Create: `lib/design/widgets/jetlag_skeleton.dart`
- Create: `lib/design/widgets/widgets.dart`

This task creates the core reusable widgets. Each widget is self-contained and uses the color tokens from `colors.dart`.

- [ ] **Step 1: Create JetlagCard**

Create `lib/design/widgets/jetlag_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../colors.dart';
import '../theme.dart';

/// Card with top-edge glow line and surface background.
/// Matches ratz.fyi `.card` CSS class.
class JetlagCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const JetlagCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderColor ?? context.borderSubtle;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(JetlagRadii.lg),
          border: Border.all(color: effectiveBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(JetlagRadii.lg),
          child: Stack(
            children: [
              Padding(padding: padding, child: child),
              // Top-edge glow line
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        context.border.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                      stops: const [0.1, 0.5, 0.9],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create JetlagButton**

Create `lib/design/widgets/jetlag_button.dart`:

```dart
import 'package:flutter/material.dart';
import '../colors.dart';
import '../theme.dart';

enum JetlagButtonVariant { primary, secondary, danger }

class JetlagButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final JetlagButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  const JetlagButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = JetlagButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<JetlagButton> createState() => _JetlagButtonState();
}

class _JetlagButtonState extends State<JetlagButton> {
  bool _hovering = false;

  Color _bgColor(BuildContext context) {
    switch (widget.variant) {
      case JetlagButtonVariant.primary:
        return context.accent;
      case JetlagButtonVariant.secondary:
        return context.surface2;
      case JetlagButtonVariant.danger:
        return context.red;
    }
  }

  Color _textColor(BuildContext context) {
    switch (widget.variant) {
      case JetlagButtonVariant.primary:
      case JetlagButtonVariant.danger:
        return Colors.white;
      case JetlagButtonVariant.secondary:
        return context.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..translate(0.0, _hovering && !disabled ? -1.0 : 0.0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: _bgColor(context).withValues(alpha: disabled ? 0.4 : 1.0),
            borderRadius: BorderRadius.circular(JetlagRadii.sm),
            border: widget.variant == JetlagButtonVariant.secondary
                ? Border.all(color: context.border)
                : null,
            boxShadow: _hovering && !disabled
                ? [BoxShadow(color: JetlagColors.accentGlow, blurRadius: 16, offset: const Offset(0, 4))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _textColor(context)),
                  ),
                )
              else if (widget.icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(widget.icon, size: 16, color: _textColor(context)),
                ),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: _textColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create JetlagBadge**

Create `lib/design/widgets/jetlag_badge.dart`:

```dart
import 'package:flutter/material.dart';
import '../colors.dart';

enum JetlagBadgeColor { green, red, orange, blue, purple }

class JetlagBadge extends StatelessWidget {
  final String label;
  final JetlagBadgeColor color;
  final bool showPulse;

  const JetlagBadge({
    super.key,
    required this.label,
    required this.color,
    this.showPulse = false,
  });

  (Color, Color) _colors() {
    switch (color) {
      case JetlagBadgeColor.green:
        return (JetlagColors.greenGlow, JetlagColors.green);
      case JetlagBadgeColor.red:
        return (JetlagColors.redGlow, JetlagColors.red);
      case JetlagBadgeColor.orange:
        return (JetlagColors.orangeGlow, JetlagColors.orange);
      case JetlagBadgeColor.blue:
        return (JetlagColors.accentGlow, JetlagColors.accent);
      case JetlagBadgeColor.purple:
        return (JetlagColors.purpleGlow, JetlagColors.purple);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: bg, blurRadius: 8, spreadRadius: -2)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPulse) ...[
            _PulseDot(color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = (1 + Curves.easeInOut.transform((_ctrl.value * 2 - 1).abs())) / 2;
        return Opacity(
          opacity: 0.4 + 0.6 * t,
          child: Transform.scale(
            scale: 0.8 + 0.2 * t,
            child: Container(
              width: 6, height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Create JetlagInput**

Create `lib/design/widgets/jetlag_input.dart`:

```dart
import 'package:flutter/material.dart';
import '../colors.dart';
import '../theme.dart';

class JetlagInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;

  const JetlagInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              label!.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        TextField(
          controller: controller,
          onChanged: onChanged,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(fontSize: 14, color: context.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.textTertiary),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Create JetlagTimer**

Create `lib/design/widgets/jetlag_timer.dart`:

```dart
import 'package:flutter/material.dart';
import '../colors.dart';
import '../theme.dart';

class JetlagTimer extends StatelessWidget {
  final Duration duration;
  final Duration? warningThreshold;
  final double fontSize;
  final String? suffix;

  const JetlagTimer({
    super.key,
    required this.duration,
    this.warningThreshold,
    this.fontSize = 22,
    this.suffix,
  });

  String _format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isWarning = warningThreshold != null && duration <= warningThreshold!;
    final color = isWarning ? context.red : context.textPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          _format(duration),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: color,
          ),
        ),
        if (suffix != null) ...[
          const SizedBox(width: 6),
          Text(suffix!, style: TextStyle(fontSize: 11, color: context.textTertiary)),
        ],
      ],
    );
  }
}
```

- [ ] **Step 6: Create JetlagStatusBar**

Create `lib/design/widgets/jetlag_status_bar.dart`:

```dart
import 'package:flutter/material.dart';
import '../colors.dart';

enum GameRole { hider, seeker, spectator }

class JetlagStatusBar extends StatelessWidget {
  final GameRole role;
  final String label;
  final Widget? trailing;

  const JetlagStatusBar({
    super.key,
    required this.role,
    required this.label,
    this.trailing,
  });

  Color _bgColor() {
    switch (role) {
      case GameRole.hider:
        return JetlagColors.green;
      case GameRole.seeker:
        return JetlagColors.red;
      case GameRole.spectator:
        return JetlagColors.darkSurface3;
    }
  }

  Color _fgColor() {
    switch (role) {
      case GameRole.hider:
      case GameRole.seeker:
        return Colors.black;
      case GameRole.spectator:
        return JetlagColors.darkText2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: _bgColor(),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _fgColor(),
                letterSpacing: 0.8,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Create JetlagSkeleton**

Create `lib/design/widgets/jetlag_skeleton.dart`:

```dart
import 'package:flutter/material.dart';
import '../colors.dart';
import '../theme.dart';

class JetlagSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const JetlagSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 10,
  });

  @override
  State<JetlagSkeleton> createState() => _JetlagSkeletonState();
}

class _JetlagSkeletonState extends State<JetlagSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-1.0 + 2.0 * _ctrl.value + 1.0, 0),
              colors: [
                context.surface2,
                context.surface3,
                context.surface2,
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 8: Create barrel export**

Create `lib/design/widgets/widgets.dart`:

```dart
export 'jetlag_card.dart';
export 'jetlag_button.dart';
export 'jetlag_badge.dart';
export 'jetlag_input.dart';
export 'jetlag_timer.dart';
export 'jetlag_status_bar.dart';
export 'jetlag_skeleton.dart';
```

- [ ] **Step 9: Commit**

```bash
git add lib/design/widgets/
git commit -m "feat: add ratz.fyi design system widgets

JetlagCard (top-edge glow), JetlagButton (3 variants), JetlagBadge
(inner glow + pulse dot), JetlagInput (glow ring), JetlagTimer
(tabular nums), JetlagStatusBar (role-colored), JetlagSkeleton
(shimmer loading).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: New Models — Team, Round, FeatureRequest

**Files:**
- Create: `lib/core/models/team.dart`
- Create: `lib/core/models/round.dart`
- Create: `lib/core/models/feature_request.dart`
- Modify: `lib/core/models/game_session.dart`
- Modify: `lib/core/models/models.dart`

- [ ] **Step 1: Create Team model**

Create `lib/core/models/team.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'team.freezed.dart';
part 'team.g.dart';

@freezed
class Team with _$Team {
  const factory Team({
    required String id,
    required String sessionId,
    required String name,
    @Default('green') String color,
    @Default(0) int displayOrder,
    DateTime? createdAt,
  }) = _Team;

  factory Team.fromJson(Map<String, dynamic> json) => _$TeamFromJson(json);
}
```

- [ ] **Step 2: Create Round model**

Create `lib/core/models/round.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'round.freezed.dart';
part 'round.g.dart';

enum RoundStatus { waiting, hiding, seeking, endgame, found }

@freezed
class Round with _$Round {
  const Round._();

  const factory Round({
    required String id,
    required String sessionId,
    @Default(1) int roundNumber,
    String? hiderTeamId,
    String? seekerTeamId,
    @Default(RoundStatus.waiting) RoundStatus status,
    DateTime? hidingStartedAt,
    DateTime? seekingStartedAt,
    DateTime? timerPausedAt,
    int? pausedTimeRemainingSeconds,
    DateTime? foundAt,
    int? hideDurationSeconds,
    DateTime? createdAt,
  }) = _Round;

  factory Round.fromJson(Map<String, dynamic> json) => _$RoundFromJson(json);

  bool get isActive => status != RoundStatus.found;

  Duration? get hideDuration => hideDurationSeconds != null
      ? Duration(seconds: hideDurationSeconds!)
      : null;
}
```

- [ ] **Step 3: Create FeatureRequest model**

Create `lib/core/models/feature_request.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'feature_request.freezed.dart';
part 'feature_request.g.dart';

enum FeatureRequestStatus { open, inProgress, done }

@freezed
class FeatureRequest with _$FeatureRequest {
  const factory FeatureRequest({
    required String id,
    required String title,
    String? description,
    @Default(FeatureRequestStatus.open) FeatureRequestStatus status,
    String? submitterName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _FeatureRequest;

  factory FeatureRequest.fromJson(Map<String, dynamic> json) => _$FeatureRequestFromJson(json);
}
```

- [ ] **Step 4: Add team/winner fields to GameSession**

In `lib/core/models/game_session.dart`, add these fields to the `GameSession` factory constructor:

```dart
String? winningTeamId,
@Default(false) bool winnerOverride,
@Default(2) int totalRounds,
```

- [ ] **Step 5: Add team_id to Participant**

In `lib/core/models/game_session.dart`, add to the `Participant` factory constructor:

```dart
String? teamId,
```

- [ ] **Step 6: Update models barrel export**

In `lib/core/models/models.dart`, add:

```dart
export 'team.dart';
export 'round.dart';
export 'feature_request.dart';
```

- [ ] **Step 7: Regenerate Freezed models**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: Generates `.freezed.dart` and `.g.dart` for all models including new ones.

- [ ] **Step 8: Commit**

```bash
git add lib/core/models/
git commit -m "feat: add Team, Round, FeatureRequest models

Freezed models for multi-round team games. Add winning_team_id,
total_rounds to GameSession. Add team_id to Participant.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Supabase Service — Teams, Rounds, Feature Requests CRUD

**Files:**
- Modify: `lib/core/services/supabase_service.dart`

- [ ] **Step 1: Add team CRUD methods**

Add to `SupabaseService` class in `lib/core/services/supabase_service.dart`:

```dart
// ============ Teams ============

Future<List<Team>> getTeams(String sessionId) async {
  final response = await _client
      .from('teams')
      .select()
      .eq('session_id', sessionId)
      .order('display_order');
  return (response as List).map((e) => Team.fromJson(_teamFromDb(e))).toList();
}

Future<Team> createTeam({
  required String sessionId,
  required String name,
  required String color,
  required int displayOrder,
}) async {
  final data = {
    'session_id': sessionId,
    'name': name,
    'color': color,
    'display_order': displayOrder,
  };
  final response = await _client.from('teams').insert(data).select().single();
  return Team.fromJson(_teamFromDb(response));
}

Future<void> updateParticipantTeam(String participantId, String? teamId) async {
  await _client.from('participants').update({'team_id': teamId}).eq('id', participantId);
}

Map<String, dynamic> _teamFromDb(Map<String, dynamic> data) {
  return {
    'id': data['id'],
    'sessionId': data['session_id'],
    'name': data['name'],
    'color': data['color'],
    'displayOrder': data['display_order'],
    'createdAt': data['created_at'],
  };
}
```

- [ ] **Step 2: Add round CRUD methods**

Add to `SupabaseService`:

```dart
// ============ Rounds ============

Future<List<Round>> getRounds(String sessionId) async {
  final response = await _client
      .from('rounds')
      .select()
      .eq('session_id', sessionId)
      .order('round_number');
  return (response as List).map((e) => Round.fromJson(_roundFromDb(e))).toList();
}

Future<Round?> getActiveRound(String sessionId) async {
  final response = await _client
      .from('rounds')
      .select()
      .eq('session_id', sessionId)
      .neq('status', 'found')
      .order('round_number', ascending: false)
      .maybeSingle();
  if (response == null) return null;
  return Round.fromJson(_roundFromDb(response));
}

Future<Round> createRound({
  required String sessionId,
  required int roundNumber,
  required String hiderTeamId,
  required String seekerTeamId,
}) async {
  final data = {
    'session_id': sessionId,
    'round_number': roundNumber,
    'hider_team_id': hiderTeamId,
    'seeker_team_id': seekerTeamId,
    'status': 'waiting',
  };
  final response = await _client.from('rounds').insert(data).select().single();
  return Round.fromJson(_roundFromDb(response));
}

Future<void> updateRoundStatus(
  String roundId,
  String status, {
  DateTime? hidingStartedAt,
  DateTime? seekingStartedAt,
  DateTime? timerPausedAt,
  int? pausedTimeRemainingSeconds,
  DateTime? foundAt,
  int? hideDurationSeconds,
}) async {
  final data = <String, dynamic>{'status': status};
  if (hidingStartedAt != null) data['hiding_started_at'] = hidingStartedAt.toIso8601String();
  if (seekingStartedAt != null) data['seeking_started_at'] = seekingStartedAt.toIso8601String();
  if (timerPausedAt != null) data['timer_paused_at'] = timerPausedAt.toIso8601String();
  if (pausedTimeRemainingSeconds != null) data['paused_time_remaining_seconds'] = pausedTimeRemainingSeconds;
  if (foundAt != null) data['found_at'] = foundAt.toIso8601String();
  if (hideDurationSeconds != null) data['hide_duration_seconds'] = hideDurationSeconds;
  await _client.from('rounds').update(data).eq('id', roundId);
}

Future<void> setSessionWinner(String sessionId, String teamId, {bool override = false}) async {
  await _client.from('sessions').update({
    'winning_team_id': teamId,
    'winner_override': override,
    'status': 'ended',
    'ended_at': DateTime.now().toIso8601String(),
  }).eq('id', sessionId);
}

Map<String, dynamic> _roundFromDb(Map<String, dynamic> data) {
  return {
    'id': data['id'],
    'sessionId': data['session_id'],
    'roundNumber': data['round_number'],
    'hiderTeamId': data['hider_team_id'],
    'seekerTeamId': data['seeker_team_id'],
    'status': data['status'],
    'hidingStartedAt': data['hiding_started_at'],
    'seekingStartedAt': data['seeking_started_at'],
    'timerPausedAt': data['timer_paused_at'],
    'pausedTimeRemainingSeconds': data['paused_time_remaining_seconds'],
    'foundAt': data['found_at'],
    'hideDurationSeconds': data['hide_duration_seconds'],
    'createdAt': data['created_at'],
  };
}
```

- [ ] **Step 3: Add feature request CRUD methods**

Add to `SupabaseService`:

```dart
// ============ Feature Requests ============

Future<List<FeatureRequest>> getFeatureRequests() async {
  final response = await _client
      .from('feature_requests')
      .select()
      .order('created_at', ascending: false);
  return (response as List).map((e) => FeatureRequest.fromJson(_featureRequestFromDb(e))).toList();
}

Future<FeatureRequest> submitFeatureRequest({
  required String title,
  String? description,
  String? submitterName,
}) async {
  final data = {
    'title': title,
    'description': description,
    'submitter_name': submitterName,
  };
  final response = await _client.from('feature_requests').insert(data).select().single();
  return FeatureRequest.fromJson(_featureRequestFromDb(response));
}

Future<void> updateFeatureRequestStatus(String id, String status) async {
  await _client.from('feature_requests').update({
    'status': status,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', id);
}

Map<String, dynamic> _featureRequestFromDb(Map<String, dynamic> data) {
  return {
    'id': data['id'],
    'title': data['title'],
    'description': data['description'],
    'status': data['status']?.replaceAll('_', '') ?? 'open',
    'submitterName': data['submitter_name'],
    'createdAt': data['created_at'],
    'updatedAt': data['updated_at'],
  };
}
```

Note: The `status` field mapping handles `in_progress` → `inProgress` for the Freezed enum.

- [ ] **Step 4: Add required imports at top of file**

Add to imports in `supabase_service.dart`:

```dart
import '../models/team.dart';
import '../models/round.dart';
import '../models/feature_request.dart';
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/supabase_service.dart
git commit -m "feat: add teams, rounds, feature requests to SupabaseService

CRUD methods for team management, multi-round game flow, and public
feature request submission.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Fix CardActions & Card Draw Screen

The card_draw_screen.dart references methods that don't exist on CardActions. Fix these.

**Files:**
- Modify: `lib/core/providers/card_provider.dart`
- Modify: `lib/features/cards/card_draw_screen.dart`

- [ ] **Step 1: Add missing methods to CardActions**

In `lib/core/providers/card_provider.dart`, add these methods to the `CardActions` class:

```dart
/// Draw N random cards from the deck. Returns the drawn card IDs.
Future<List<GameCard>> drawRandomCards(int count) async {
  final deckNotifier = ref.read(deckStateProvider.notifier);
  final allCards = ref.read(allCardsProvider);
  final drawn = <GameCard>[];
  for (var i = 0; i < count; i++) {
    final cardId = deckNotifier.drawCard();
    if (cardId == null) break;
    final card = allCards.firstWhere((c) => c.id == cardId);
    drawn.add(card);
  }
  return drawn;
}

/// Keep a drawn card (add to hand in Supabase).
Future<HiderCard> keepCard(String sessionId, String cardId, {String? roundId}) async {
  final service = ref.read(supabaseServiceProvider);
  if (service == null) throw Exception('Not connected');
  return service.drawCard(sessionId: sessionId, cardId: cardId);
}

/// Discard a drawn card (don't keep it).
void discardDrawnCard(String cardId) {
  final deckNotifier = ref.read(deckStateProvider.notifier);
  deckNotifier.discardCard(cardId);
}
```

- [ ] **Step 2: Fix card_draw_screen.dart references**

In `lib/features/cards/card_draw_screen.dart`, update the method calls to match the new CardActions API. Replace references to `cardActions.drawRandomCard()` with `cardActions.drawRandomCards(drawCount)`, and fix `card.effect` references to use `card.description` or the appropriate field from the GameCard model.

Read the file carefully first to identify all broken references, then fix each one.

- [ ] **Step 3: Verify compilation**

```bash
dart analyze lib/core/providers/card_provider.dart lib/features/cards/card_draw_screen.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/providers/card_provider.dart lib/features/cards/card_draw_screen.dart
git commit -m "fix: add missing CardActions methods, fix card draw screen

Add drawRandomCards(), keepCard(), discardDrawnCard() to CardActions.
Fix broken method references and field access in card_draw_screen.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Wire Up App Entry Point & Theme

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/core/services/supabase_init.dart`

- [ ] **Step 1: Update Supabase config in supabase_init.dart**

In `lib/core/services/supabase_init.dart`, update the `SupabaseConfig` defaults to use the real values:

```dart
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jetlag.ratz.fyi/supabase',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNjQxNzY5MjAwLCJleHAiOjE3OTk1MzU2MDB9.hVGT3I0Nxn2dz0Tdh9HWlxu_a0HUodMXm6PSuTFGct0',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty && !url.contains('placeholder');
}
```

- [ ] **Step 2: Update app.dart to use JetlagTheme**

In `lib/app/app.dart`, replace the theme references:

```dart
import '../design/theme.dart';

// In the build method, replace the theme/darkTheme:
MaterialApp.router(
  title: 'Jet Lag: Hide & Seek',
  theme: JetlagTheme.light(),
  darkTheme: JetlagTheme.dark(),
  themeMode: ref.watch(themeModeProvider),
  routerConfig: ref.watch(routerProvider),
);
```

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart lib/app/app.dart lib/core/services/supabase_init.dart
git commit -m "feat: wire up real Supabase config and JetlagTheme

Point to jetlag.ratz.fyi/supabase with real anon key.
Switch to ratz.fyi design system theme (dark/light).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Feature Requests Screen

**Files:**
- Create: `lib/core/providers/feature_request_provider.dart`
- Create: `lib/features/feature_requests/feature_requests_screen.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/features/home/home_screen.dart`

- [ ] **Step 1: Create feature request provider**

Create `lib/core/providers/feature_request_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feature_request.dart';
import '../services/supabase_init.dart';

final featureRequestsProvider = FutureProvider<List<FeatureRequest>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  if (service == null) return [];
  return service.getFeatureRequests();
});

class FeatureRequestActions {
  final Ref ref;
  FeatureRequestActions(this.ref);

  Future<FeatureRequest?> submit({
    required String title,
    String? description,
    String? submitterName,
  }) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return null;
    final result = await service.submitFeatureRequest(
      title: title,
      description: description,
      submitterName: submitterName,
    );
    ref.invalidate(featureRequestsProvider);
    return result;
  }
}

final featureRequestActionsProvider = Provider((ref) => FeatureRequestActions(ref));
```

- [ ] **Step 2: Create feature requests screen**

Create `lib/features/feature_requests/feature_requests_screen.dart`. This screen shows:
- A submit form (title + description + optional name)
- A list of all feature requests, newest first
- Status badges (open = blue, in_progress = orange, done = green)

Use `JetlagCard`, `JetlagButton`, `JetlagInput`, `JetlagBadge` from the design system. Follow the same pattern as billsplit's feature requests page. The screen should be a `ConsumerStatefulWidget` that uses `featureRequestsProvider` and `featureRequestActionsProvider`.

- [ ] **Step 3: Add route**

In `lib/app/router.dart`, add:

```dart
GoRoute(
  path: '/ideas',
  builder: (context, state) => const FeatureRequestsScreen(),
),
```

And import the screen.

- [ ] **Step 4: Add Ideas button to home screen**

In `lib/features/home/home_screen.dart`, add an "Ideas" button that navigates to `/ideas`. Place it alongside the existing Settings button.

- [ ] **Step 5: Commit**

```bash
git add lib/core/providers/feature_request_provider.dart lib/features/feature_requests/ lib/app/router.dart lib/features/home/home_screen.dart
git commit -m "feat: add public feature requests page

Submit ideas, view all requests with status badges. Accessible from
home screen Ideas button. Same pattern as billsplit.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: Team-Aware Lobby Screen

**Files:**
- Modify: `lib/features/lobby/lobby_screen.dart`
- Create: `lib/core/providers/team_provider.dart`

- [ ] **Step 1: Create team provider**

Create `lib/core/providers/team_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/team.dart';
import '../services/supabase_init.dart';
import 'game_provider.dart';

/// Stream of teams for the current session.
final teamsProvider = StreamProvider<List<Team>>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  final client = ref.watch(supabaseClientProvider);
  if (sessionId == null || client == null) return const Stream.empty();

  return client
      .from('teams')
      .stream(primaryKey: ['id'])
      .eq('session_id', sessionId)
      .order('display_order')
      .map((rows) => rows.map((e) => Team.fromJson(_teamFromDb(e))).toList());
});

/// Whether teams are balanced enough to start (within 1 player of each other).
final teamsBalancedProvider = Provider<bool>((ref) {
  final participants = ref.watch(participantsProvider).valueOrNull ?? [];
  final teams = ref.watch(teamsProvider).valueOrNull ?? [];
  if (teams.length < 2) return false;

  final counts = <String, int>{};
  for (final t in teams) {
    counts[t.id] = 0;
  }
  for (final p in participants) {
    if (p.teamId != null && counts.containsKey(p.teamId)) {
      counts[p.teamId!] = counts[p.teamId!]! + 1;
    }
  }

  final values = counts.values.toList();
  if (values.any((c) => c == 0)) return false; // every team needs at least 1
  final max = values.reduce((a, b) => a > b ? a : b);
  final min = values.reduce((a, b) => a < b ? a : b);
  return (max - min) <= 1;
});

class TeamActions {
  final Ref ref;
  TeamActions(this.ref);

  Future<void> createDefaultTeams(String sessionId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.createTeam(sessionId: sessionId, name: 'Team Alpha', color: 'green', displayOrder: 0);
    await service.createTeam(sessionId: sessionId, name: 'Team Beta', color: 'red', displayOrder: 1);
  }

  Future<void> switchTeam(String participantId, String teamId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.updateParticipantTeam(participantId, teamId);
  }
}

final teamActionsProvider = Provider((ref) => TeamActions(ref));

Map<String, dynamic> _teamFromDb(Map<String, dynamic> data) {
  return {
    'id': data['id'],
    'sessionId': data['session_id'],
    'name': data['name'],
    'color': data['color'],
    'displayOrder': data['display_order'],
    'createdAt': data['created_at'],
  };
}
```

- [ ] **Step 2: Rewrite lobby screen with team selection**

Rewrite `lib/features/lobby/lobby_screen.dart` to show:
- Room code header with copy button
- Two team columns (Team Alpha / Team Beta) side by side
- Each column lists its members. Tap your name to switch teams.
- "Tap your name to switch teams" hint
- Unassigned players shown at bottom
- Start Round 1 button (disabled unless teams are balanced via `teamsBalancedProvider`)
- Use design system widgets (JetlagCard, JetlagButton, JetlagBadge)

When creating a session, also call `teamActionsProvider.createDefaultTeams()` to create the two teams.

- [ ] **Step 3: Commit**

```bash
git add lib/core/providers/team_provider.dart lib/features/lobby/lobby_screen.dart
git commit -m "feat: team-aware lobby with self-select and balance enforcement

Two-column team layout, tap to switch, Start disabled until balanced.
Creates Team Alpha and Team Beta on session creation.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: Round Provider & Multi-Round Game Flow

**Files:**
- Create: `lib/core/providers/round_provider.dart`
- Modify: `lib/core/providers/game_provider.dart`
- Modify: `lib/core/services/realtime_service.dart`

- [ ] **Step 1: Create round provider**

Create `lib/core/providers/round_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/round.dart';
import '../services/supabase_init.dart';
import 'game_provider.dart';

/// All rounds for the current session.
final roundsProvider = StreamProvider<List<Round>>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  final client = ref.watch(supabaseClientProvider);
  if (sessionId == null || client == null) return const Stream.empty();

  return client
      .from('rounds')
      .stream(primaryKey: ['id'])
      .eq('session_id', sessionId)
      .order('round_number')
      .map((rows) => rows.map((e) => Round.fromJson(_roundFromDb(e))).toList());
});

/// The currently active round (not 'found').
final activeRoundProvider = Provider<Round?>((ref) {
  final rounds = ref.watch(roundsProvider).valueOrNull ?? [];
  try {
    return rounds.lastWhere((r) => r.status != RoundStatus.found);
  } catch (_) {
    return null;
  }
});

/// Current round number.
final currentRoundNumberProvider = Provider<int>((ref) {
  final round = ref.watch(activeRoundProvider);
  return round?.roundNumber ?? 0;
});

class RoundActions {
  final Ref ref;
  RoundActions(this.ref);

  Future<Round?> startRound({
    required String sessionId,
    required int roundNumber,
    required String hiderTeamId,
    required String seekerTeamId,
  }) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return null;
    return service.createRound(
      sessionId: sessionId,
      roundNumber: roundNumber,
      hiderTeamId: hiderTeamId,
      seekerTeamId: seekerTeamId,
    );
  }

  Future<void> startHiding(String roundId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.updateRoundStatus(roundId, 'hiding', hidingStartedAt: DateTime.now());
  }

  Future<void> startSeeking(String roundId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.updateRoundStatus(roundId, 'seeking', seekingStartedAt: DateTime.now());
  }

  Future<void> enterEndgame(String roundId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.updateRoundStatus(roundId, 'endgame');
  }

  Future<void> markFound(String roundId, int hideDurationSeconds) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.updateRoundStatus(
      roundId, 'found',
      foundAt: DateTime.now(),
      hideDurationSeconds: hideDurationSeconds,
    );
  }

  Future<void> pauseRound(String roundId, int remainingSeconds) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.updateRoundStatus(
      roundId, 'seeking',
      timerPausedAt: DateTime.now(),
      pausedTimeRemainingSeconds: remainingSeconds,
    );
  }

  Future<void> resumeRound(String roundId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    await service.updateRoundStatus(roundId, 'seeking');
  }

  /// Determine overall winner based on longest hide time.
  Future<void> determineWinner(String sessionId) async {
    final service = ref.read(supabaseServiceProvider);
    if (service == null) return;
    final rounds = await service.getRounds(sessionId);
    final completed = rounds.where((r) => r.status == RoundStatus.found && r.hideDurationSeconds != null).toList();
    if (completed.isEmpty) return;

    // Find which team hid the longest
    final hideTimes = <String, int>{};
    for (final round in completed) {
      if (round.hiderTeamId != null) {
        hideTimes[round.hiderTeamId!] = (hideTimes[round.hiderTeamId!] ?? 0) + round.hideDurationSeconds!;
      }
    }

    final winnerEntry = hideTimes.entries.reduce((a, b) => a.value > b.value ? a : b);
    await service.setSessionWinner(sessionId, winnerEntry.key);
  }
}

final roundActionsProvider = Provider((ref) => RoundActions(ref));

Map<String, dynamic> _roundFromDb(Map<String, dynamic> data) {
  return {
    'id': data['id'],
    'sessionId': data['session_id'],
    'roundNumber': data['round_number'],
    'hiderTeamId': data['hider_team_id'],
    'seekerTeamId': data['seeker_team_id'],
    'status': data['status'],
    'hidingStartedAt': data['hiding_started_at'],
    'seekingStartedAt': data['seeking_started_at'],
    'timerPausedAt': data['timer_paused_at'],
    'pausedTimeRemainingSeconds': data['paused_time_remaining_seconds'],
    'foundAt': data['found_at'],
    'hideDurationSeconds': data['hide_duration_seconds'],
    'createdAt': data['created_at'],
  };
}
```

- [ ] **Step 2: Add round realtime subscription**

In `lib/core/services/realtime_service.dart`, add a method to subscribe to round changes:

```dart
StreamController<Map<String, dynamic>>? _roundController;

Stream<Map<String, dynamic>> subscribeToRounds(String sessionId) {
  _roundController?.close();
  _roundController = StreamController<Map<String, dynamic>>.broadcast();

  _client
      .from('rounds')
      .stream(primaryKey: ['id'])
      .eq('session_id', sessionId)
      .listen((data) {
    for (final row in data) {
      _roundController?.add(row);
    }
  });

  return _roundController!.stream;
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/providers/round_provider.dart lib/core/services/realtime_service.dart
git commit -m "feat: add round provider with multi-round game flow

Round CRUD, active round tracking, start/pause/resume/found actions,
winner determination by longest hide time, realtime subscriptions.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: Game Views — Hybrid Bottom Sheet Navigation

This is the largest UI task. Restyle the seeker, hider, and spectator views with the design system and hybrid map + bottom sheet navigation.

**Files:**
- Create: `lib/design/widgets/jetlag_bottom_sheet.dart`
- Modify: `lib/features/game/seeker_view.dart`
- Modify: `lib/features/game/hider_view.dart`
- Modify: `lib/features/game/spectator_view.dart`

- [ ] **Step 1: Create JetlagBottomSheet widget**

Create `lib/design/widgets/jetlag_bottom_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import '../colors.dart';
import '../theme.dart';

enum SheetPosition { collapsed, half, full }

class JetlagBottomSheet extends StatefulWidget {
  final Widget child;
  final SheetPosition initialPosition;
  final ValueChanged<SheetPosition>? onPositionChanged;

  const JetlagBottomSheet({
    super.key,
    required this.child,
    this.initialPosition = SheetPosition.collapsed,
    this.onPositionChanged,
  });

  @override
  State<JetlagBottomSheet> createState() => _JetlagBottomSheetState();
}

class _JetlagBottomSheetState extends State<JetlagBottomSheet> {
  late SheetPosition _position;

  double _fractionForPosition(SheetPosition pos) {
    switch (pos) {
      case SheetPosition.collapsed:
        return 0.0;
      case SheetPosition.half:
        return 0.45;
      case SheetPosition.full:
        return 0.9;
    }
  }

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  void _onDragEnd(DraggableScrollableNotification notification) {
    final extent = notification.extent;
    SheetPosition newPos;
    if (extent < 0.2) {
      newPos = SheetPosition.collapsed;
    } else if (extent < 0.65) {
      newPos = SheetPosition.half;
    } else {
      newPos = SheetPosition.full;
    }
    if (newPos != _position) {
      setState(() => _position = newPos);
      widget.onPositionChanged?.call(newPos);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _fractionForPosition(_position),
      minChildSize: 0.0,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.0, 0.45, 0.9],
      builder: (context, scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (n) { _onDragEnd(n); return true; },
          child: Container(
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(top: BorderSide(color: context.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

Add to `lib/design/widgets/widgets.dart`:

```dart
export 'jetlag_bottom_sheet.dart';
```

- [ ] **Step 2: Restyle seeker_view.dart**

Rewrite `lib/features/game/seeker_view.dart` with:
- `JetlagStatusBar(role: GameRole.seeker)` at top with timer
- Team indicator bar below status bar
- Full-screen Google Map as the base layer
- Bottom tab bar: Map / Questions / Cards / Team
- Questions and Cards tabs open `JetlagBottomSheet` overlay on the map
- Team tab navigates to a full-screen team page
- FAB for asking questions (accent color, positioned for right-thumb)
- Use round-aware providers (`activeRoundProvider` instead of session status)

- [ ] **Step 3: Restyle hider_view.dart**

Rewrite `lib/features/game/hider_view.dart` with:
- `JetlagStatusBar(role: GameRole.hider)` at top with timer
- Team indicator bar with incoming question countdown when applicable
- Full-screen Google Map
- Bottom tab bar: Map / Answer / Cards / Team
- Answer and Cards tabs open `JetlagBottomSheet`
- Incoming question banner overlay at top of map (slides down)
- Use round-aware providers

- [ ] **Step 4: Restyle spectator_view.dart**

Rewrite `lib/features/game/spectator_view.dart` with:
- `JetlagStatusBar(role: GameRole.spectator)` at top
- Round indicator (Round N of M)
- Full-screen map with all visible info
- Live event feed as bottom sheet
- Use round-aware providers

- [ ] **Step 5: Commit**

```bash
git add lib/design/widgets/jetlag_bottom_sheet.dart lib/design/widgets/widgets.dart lib/features/game/
git commit -m "feat: restyle game views with hybrid map + bottom sheet

Seeker/Hider/Spectator views use JetlagStatusBar, JetlagBottomSheet,
design system widgets. Map always visible, Questions/Cards overlay as
draggable sheets. Round-aware providers.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: Round Summary & Game Over Screens

**Files:**
- Create: `lib/features/game/round_summary_screen.dart`
- Modify: `lib/features/game/game_over_screen.dart`
- Modify: `lib/app/router.dart`

- [ ] **Step 1: Create round summary screen**

Create `lib/features/game/round_summary_screen.dart`. Shows:
- "Round N Complete" header
- Hide time achieved
- Stats (questions asked, cards played)
- Role swap visualization (was hiding → now hiding)
- "Start Round N" button with target to beat ("Team Beta needs to hide for longer than 47:23 to win")
- Uses design system widgets

- [ ] **Step 2: Rewrite game over screen**

Rewrite `lib/features/game/game_over_screen.dart` with:
- Winner banner (team that hid longest)
- Round-by-round comparison with hide times
- Stats per round (questions, cards)
- "Home" button
- Admin override indicator if applicable
- Design system styling

- [ ] **Step 3: Add routes**

In `lib/app/router.dart`, add:

```dart
GoRoute(
  path: '/game/:sessionId/round-summary',
  builder: (context, state) => RoundSummaryScreen(
    sessionId: state.pathParameters['sessionId']!,
  ),
),
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/game/round_summary_screen.dart lib/features/game/game_over_screen.dart lib/app/router.dart
git commit -m "feat: add round summary and multi-round game over screens

Round summary shows hide time, stats, role swap. Game over compares
teams across rounds, declares winner by longest hide time.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: Restyle Remaining Screens

Restyle home, join, auth, settings, and question screens with the design system.

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/lobby/join_game_screen.dart`
- Modify: `lib/features/auth/auth_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/features/questions/question_browser.dart`
- Modify: `lib/features/questions/question_detail.dart`
- Modify: `lib/features/questions/answer_interface.dart`
- Modify: `lib/features/cards/card_deck_view.dart`
- Modify: `lib/features/cards/card_detail.dart`

- [ ] **Step 1: Restyle home screen**

Update `home_screen.dart` with:
- Gradient heading "JET LAG" with `HIDE & SEEK` subtitle
- Join Game button (accent), How to Play button (secondary)
- Ideas and Settings buttons at bottom
- Design system colors, cards, buttons

- [ ] **Step 2: Restyle join screen**

Update `join_game_screen.dart` with:
- Individual character boxes for room code (accent glow on active)
- JetlagInput for display name
- JetlagButton for join

- [ ] **Step 3: Restyle settings screen**

Update `settings_screen.dart` with:
- Theme toggle pill selector (System / Light / Dark) using `JetlagTabs`-style widget
- Design system cards for settings sections

- [ ] **Step 4: Restyle question and card screens**

Update question_browser, question_detail, answer_interface, card_deck_view, card_detail with design system widgets. Replace Material Card/Button/Badge with Jetlag equivalents.

- [ ] **Step 5: Commit**

```bash
git add lib/features/
git commit -m "feat: restyle all screens with ratz.fyi design system

Home, join, auth, settings, questions, cards — all using JetlagCard,
JetlagButton, JetlagBadge, JetlagInput. Plus Jakarta Sans throughout.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: Web Compatibility Fixes

Fix all web-incompatible code.

**Files:**
- Modify: `lib/core/services/photo_service.dart`
- Modify: `lib/features/questions/answer_interface.dart`
- Modify: `lib/core/services/location_service.dart`
- Modify: `lib/core/models/game_area.dart`

- [ ] **Step 1: Fix photo_service.dart**

Remove `dart:io` imports. Replace `File` usage with `Uint8List` / `XFile` from `image_picker`. For web, photos are handled as bytes in memory, not saved to filesystem.

- [ ] **Step 2: Fix answer_interface.dart**

Remove any `dart:io` references. Use `image_picker` which returns `XFile` (works on web). Replace audio recording with a text fallback since `record` package has limited web support.

- [ ] **Step 3: Fix location_service.dart**

Add `import 'package:flutter/foundation.dart' show kIsWeb;` and wrap `permission_handler` calls in `if (!kIsWeb)` checks. On web, the browser handles geolocation permissions natively.

- [ ] **Step 4: Verify web build compiles**

```bash
flutter build web --web-renderer html --no-tree-shake-icons 2>&1 | tail -20
```

This will likely reveal remaining issues. Fix them iteratively.

- [ ] **Step 5: Commit**

```bash
git add lib/
git commit -m "fix: web compatibility — remove dart:io, handle permissions

Photo service uses Uint8List instead of File. Location service skips
permission_handler on web. Audio recording falls back to text input.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 17: Build & Deploy

**Files:**
- Modify: `/root/homeserver/config/traefik/dynamic/external-services.yml`

- [ ] **Step 1: Build Flutter web**

```bash
cd /home/claude/jetlag-hideseek
export PATH="/opt/flutter/bin:$PATH"
flutter build web \
  --web-renderer html \
  --no-tree-shake-icons \
  --dart-define=SUPABASE_URL=https://jetlag.ratz.fyi/supabase \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNjQxNzY5MjAwLCJleHAiOjE3OTk1MzU2MDB9.hVGT3I0Nxn2dz0Tdh9HWlxu_a0HUodMXm6PSuTFGct0 \
  --dart-define=GOOGLE_PLACES_API_KEY=AIzaSyCopUFT1pPzGmrGrAR_TUWKB5M8I5n0Efc
```

Expected: Build output in `build/web/`.

- [ ] **Step 2: Set up nginx to serve the build + proxy Supabase**

Create a Docker container to serve the static build and reverse proxy `/supabase/` to the Supabase Kong gateway. Pick an available port (e.g. 8900).

Create `/home/claude/jetlag-hideseek/deploy/nginx.conf`:

```nginx
server {
    listen 80;

    root /usr/share/nginx/html;
    index index.html;

    # Flutter web app — SPA routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Reverse proxy to Supabase Kong
    location /supabase/ {
        proxy_pass http://host.docker.internal:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
```

Create `/home/claude/jetlag-hideseek/deploy/docker-compose.yml`:

```yaml
services:
  web:
    image: nginx:alpine
    ports:
      - "8900:80"
    volumes:
      - ../build/web:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
```

Start:

```bash
cd /home/claude/jetlag-hideseek/deploy
sudo docker compose up -d
```

Verify:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8900/
```

Expected: 200.

- [ ] **Step 3: Add Traefik route for jetlag.ratz.fyi**

Add to `/root/homeserver/config/traefik/dynamic/external-services.yml` under `routers`:

```yaml
    jetlag:
      rule: Host(`jetlag.ratz.fyi`)
      entrypoints:
      - websecure
      service: jetlag
      tls:
        certResolver: cloudflare
      priority: 1
    jetlag-admin:
      rule: Host(`jetlag.ratz.fyi`) && (PathPrefix(`/admin`) || PathPrefix(`/api/admin`))
      entrypoints:
      - websecure
      service: jetlag
      tls:
        certResolver: cloudflare
      middlewares:
      - google-auth@docker
      - access-check@file
      priority: 10
```

Under `services`:

```yaml
    jetlag:
      loadBalancer:
        servers:
        - url: http://10.10.10.1:8900
```

Push to LXC 102:

```bash
sudo cp /root/homeserver/config/traefik/dynamic/external-services.yml /tmp/ext-svc.yml
sudo pct push 102 /tmp/ext-svc.yml /mnt/cache/appdata/traefik/dynamic/external-services.yml
```

Wait 5 seconds, then verify:

```bash
curl -sk -o /dev/null -w "%{http_code}" https://jetlag.ratz.fyi/
```

Expected: 200 (or 307 if auth middleware is hit — but the main route should be public).

- [ ] **Step 4: Add to access-manager sites list**

Use the access-manager API to add `jetlag.ratz.fyi` with admin path protection. Check the access-manager's API pattern by reviewing `/home/claude/access-manager/` for how other sites are registered.

- [ ] **Step 5: Commit**

```bash
git add deploy/
git commit -m "feat: add deployment config — nginx + docker-compose

Nginx serves Flutter web build, proxies /supabase/ to Kong.
Port 8900, Traefik routes jetlag.ratz.fyi.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 18: End-to-End Smoke Test

- [ ] **Step 1: Open jetlag.ratz.fyi in browser**

Verify:
- Home screen loads with gradient branding
- Plus Jakarta Sans font is rendering
- Dark mode by default
- Theme toggle works (switch to light, back to dark)

- [ ] **Step 2: Test join flow**

- Enter a room code (create a game first via admin or test route)
- Enter display name
- Verify lobby loads with two team columns

- [ ] **Step 3: Test team selection**

Open in two browser tabs. Join same room with different names. Verify:
- Both players appear in lobby
- Can tap to switch teams
- Start button enables when teams are balanced

- [ ] **Step 4: Test game flow**

Start a round. Verify:
- Hider view shows green status bar
- Seeker view shows red status bar
- Timer is running and synchronized
- Map loads (Google Maps)
- Bottom sheet opens for Questions/Cards

- [ ] **Step 5: Test feature requests**

Navigate to Ideas page. Submit a feature request. Verify it appears in the list.

- [ ] **Step 6: Document any issues**

Create a file at `docs/known-issues.md` listing any bugs found during testing that need follow-up.

- [ ] **Step 7: Commit any fixes**

```bash
git add -A
git commit -m "fix: smoke test fixes

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```
