# Jet Lag: Hide & Seek Companion App

A cross-platform companion app for playing Jet Lag: The Game Hide and Seek (seasons 12/16 format).

## Features

- **Game Area Definition**: Draw custom game boundaries with polygon editor
- **Session Management**: 6-character room codes, no account required
- **Real-time Sync**: Live updates between all players via Supabase
- **Question System**: All 76 questions across 5 categories with test mode
- **Card System**: Time bonuses, powerups, curses, and time traps
- **Timer System**: Server-authoritative with effective time calculation
- **Multi-role Support**: Hider, Seekers, and Spectators

## Getting Started

### Prerequisites

- Flutter 3.2.0 or higher
- A Supabase account
- Google Maps API key

### Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/jetlag-hideseek.git
cd jetlag-hideseek
```

2. Copy environment file and add your keys:
```bash
cp .env.example .env
# Edit .env with your API keys
```

3. Set up Supabase:
   - Create a new Supabase project
   - Run the migrations in `supabase/migrations/`
   - Enable Realtime for the tables
   - Copy your project URL and anon key to `.env`

4. Get Google Maps API Key:
   - Go to Google Cloud Console
   - Enable Maps SDK for Android/iOS
   - Create an API key
   - Add to `.env` and configure in platform files

5. Install dependencies:
```bash
flutter pub get
```

6. Generate model code:
```bash
dart run build_runner build --delete-conflicting-outputs
```

7. Run the app:
```bash
flutter run
```

### Platform Configuration

#### iOS
Add Google Maps API key to `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_API_KEY")
```

#### Android
Add Google Maps API key to `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY"/>
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── app/
│   ├── app.dart             # App widget
│   ├── router.dart          # Navigation routes
│   └── theme.dart           # App theme
├── features/
│   ├── auth/                # Authentication
│   ├── home/                # Home screen
│   ├── game_area/           # Polygon editor
│   ├── lobby/               # Game lobby
│   ├── game/                # Game views
│   ├── questions/           # Question system
│   └── cards/               # Card system
├── core/
│   ├── models/              # Data models (freezed)
│   ├── services/            # Backend services
│   └── providers/           # Riverpod providers
└── shared/
    ├── widgets/             # Shared widgets
    └── utils/               # Utilities
```

## Question Categories

| Category | Cost | Cards | Response Time |
|----------|------|-------|---------------|
| Relative | 40 coins | 2 | 5 min |
| Radar | 30 coins | 2 | 5 min |
| Photo | 15 coins | 1 | 10-20 min |
| Oddball | 10 coins | 1 | 5 min |
| Precision | 10 coins | 1 | 5 min |

## Card Types

- **Time Bonuses**: +5/10/15 min or +10%
- **Powerups**: Veto, Randomize, Discard & Draw, Move, Duplicate
- **Curses**: Express Route, Long Shot, Runner, Museum
- **Time Traps**: Place at stations for bonus time

## Development

### Running Tests
```bash
flutter test
```

### Building for Release

Android:
```bash
flutter build appbundle
```

iOS:
```bash
flutter build ios --release
```

Web (Spectator mode):
```bash
flutter build web --web-renderer html
```

## Contributing

Contributions are welcome! Please read our contributing guidelines first.

## License

This project is for personal/educational use. Jet Lag: The Game is a trademark of Wendover Productions.

## Acknowledgments

- [Jet Lag: The Game](https://www.youtube.com/jetlagthegame) by Wendover Productions
- [Jet Lag Wiki](https://jetlag.fandom.com/wiki/Jet_Lag:_The_Game_Wiki) for game rules
- [Official Expansion Rules](https://rules.jetlagthegame.com/expansion/)
