# Claude Handoff Document - Jet Lag Hide & Seek App

## Project Overview

A Flutter companion app for playing Jet Lag: The Game Hide & Seek (seasons 12/16 format). Cross-platform (iOS, Android, Web spectator mode).

**GitHub:** https://github.com/parthivapsani/jetlag-hideseek

## Tech Stack

- **Frontend:** Flutter 3.x with Material 3
- **State Management:** Riverpod
- **Backend:** Supabase (PostgreSQL, Realtime, Storage)
- **Maps:** Google Maps Flutter (required - source of truth for the game)
- **Models:** Freezed for immutable data classes
- **Navigation:** GoRouter

## Project Structure

```
lib/
├── app/
│   ├── app.dart          # Main app widget with theme
│   ├── router.dart       # GoRouter routes
│   └── theme.dart        # JetLagTheme (light/dark)
├── core/
│   ├── models/           # Freezed data models
│   │   ├── game_area.dart
│   │   ├── game_session.dart
│   │   ├── question.dart
│   │   ├── card.dart
│   │   └── station.dart
│   ├── providers/        # Riverpod providers
│   │   ├── auth_provider.dart
│   │   ├── game_provider.dart
│   │   ├── question_provider.dart
│   │   ├── card_provider.dart
│   │   ├── timer_provider.dart
│   │   └── game_state_provider.dart
│   └── services/
│       ├── supabase_service.dart
│       ├── realtime_service.dart
│       ├── location_service.dart
│       ├── nominatim_service.dart
│       ├── travel_estimator.dart
│       └── station_service.dart
├── features/
│   ├── auth/
│   ├── home/
│   ├── game_area/        # Polygon editor for game boundaries
│   ├── lobby/
│   ├── game/
│   │   ├── seeker_view.dart
│   │   ├── hider_view.dart
│   │   ├── spectator_view.dart
│   │   └── game_map.dart
│   ├── questions/
│   │   ├── question_browser.dart
│   │   ├── question_drafting_screen.dart  # NEW - map visualization
│   │   ├── question_detail.dart
│   │   └── answer_interface.dart
│   ├── cards/
│   └── settings/
└── shared/
    ├── widgets/
    └── utils/
```

## Key Concepts

### Question Categories (Season 12/16 Rules)

NO COINS - card-based economy only:

| Category | Draw | Keep | Question Format |
|----------|------|------|-----------------|
| Matching | 3 | 1 | "Is your X the same as our X?" |
| Measuring | 3 | 1 | "Are you closer to X than we are?" |
| Radar | 2 | 1 | "Are you within X distance of us?" |
| Thermometer | 2 | 1 | "We've moved X, warmer or colder?" |
| Tentacles | 4 | 2 | "Of all X near us, which is closest to you?" |
| Photo | 1 | 1 | "Send us a picture of X" |

### Squish Boundary (Uncertainty Zone)

Since the hider can move within their hiding zone (default 0.5 miles), questions have uncertainty:
- If asking "within 0.25 miles", actual boundary could be 0.25 + 0.5 = 0.75 miles
- Adjustable via slider (0 to 1 mile)
- Disabled in endgame (hider cannot move)

### Game Phases

```
lobby → hiding → seeking → endgame → finished
```

In **endgame**: seekers are in the hiding zone, hider cannot move, questions are exact.

## Current State

### Implemented ✓
- Project structure and all models
- Theme system (light/dark mode)
- Settings screen with theme picker
- Home screen with rules
- Question browser with all 6 categories
- Question drafting screen with map visualization:
  - Radar circles
  - Thermometer lines with bisector
  - Tentacles radius
  - Station list (included/uncertain)
  - Squish boundary slider
  - Endgame toggle
- Travel radius estimator (isochrone-like boundary)
- Basic station service (city-agnostic)

### Not Yet Implemented
- Supabase backend connection (schema exists in `/supabase/migrations/`)
- Real-time sync between players
- Card deck system UI
- Actual question submission flow
- Google Places integration for station loading (lower priority)
- Photo/audio capture for questions

## Running the App

```bash
# Install dependencies
flutter pub get

# Generate Freezed models (after changing .dart files with @freezed)
flutter pub run build_runner build --delete-conflicting-outputs

# Run on iOS simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android

# Run on Chrome (web)
flutter run -d chrome
```

## Key Files to Know

1. **Question data:** `lib/core/providers/question_provider.dart` - contains `_allQuestions` list
2. **Theme colors:** `lib/app/theme.dart` - `JetLagTheme` class with category colors
3. **Game state:** `lib/core/providers/game_state_provider.dart` - phase, squish radius, endgame
4. **Question drafting:** `lib/features/questions/question_drafting_screen.dart` - map visualization

## Design Decisions

1. **Google Maps over Leaflet:** User specified Google Maps is "source of truth" for the actual game. Could add flutter_map as free alternative later.

2. **City-agnostic stations:** Station model is generic, can load data from any source (Google Places, GTFS, manual entry).

3. **No coins:** The original plan had coins, but the official expansion rules use pure card economy.

4. **Squish boundary:** Unique feature to handle uncertainty in hider position.

## API Keys Needed

- Google Maps API key (in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/AppDelegate.swift`)
- Supabase URL and anon key (in environment or `lib/core/services/supabase_service.dart`)

## Next Steps (Suggested Priority)

1. Wire up Supabase backend
2. Implement real-time game sync
3. Add Google Places for dynamic station loading
4. Build card deck UI
5. Add photo capture for photo questions
6. Test multiplayer flow

## Notes

- The taibeled/JetLagHideAndSeek project uses Leaflet + OpenStreetMap (free) - we use Google Maps (paid but required)
- Transit line complexity (A vs C trains) not fully solved - using line names is fine for now
- App should work for any city, not just NYC
