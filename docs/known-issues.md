# Known Issues & Testing Notes

**Last updated:** 2026-04-06

## E2E Test Results

**58/58 passing** on Mobile Chrome (390x844) and Desktop Chrome (1280x720).

### Test Coverage

| Area | Tests | Status |
|------|-------|--------|
| Home page loading | 4 | Pass |
| SPA routing | 8 | Pass |
| Join game flow | 4 | Pass |
| Full game lifecycle | 12 | Pass |
| Feature requests | 2 | Pass |
| localStorage identity | 4 | Pass |
| Post-game summary | 4 | Pass |
| Replay screen | 4 | Pass |
| Event logging API | 2 | Pass |
| API usage tracking | 2 | Pass |
| Page transitions | 2 | Pass |
| Network & performance | 6 | Pass |

### What Needs Manual/Browser Testing

These require real browser interaction (not Playwright):
- **Interactive game flow**: Creating a game from home screen, joining via room code, selecting teams, starting a round
- **Real-time sync**: Two browsers seeing the same game state update in real-time
- **Google Maps interaction**: Pan/zoom, polygon display, marker placement
- **Card draw UI**: Flip animation when drawing cards
- **Question flow**: Asking a question as seeker, countdown timer on hider, answering
- **Timer accuracy**: Verify hiding/seeking timers match expected duration
- **PWA install**: Install prompt on mobile, offline behavior
- **Admin dashboard**: Requires OAuth — create game, stop game, manage feature requests, view event log, API usage stats

## Known Limitations

1. **Flutter canvas rendering**: Screenshots may appear blank if captured before Flutter initializes (~3-5 seconds). This is a known Flutter web behavior, not a bug.

2. **Event-dependent sections**: The post-game summary and replay screens show data from the `game_events` table. If a game was played before event logging was deployed (Phase 2), those games will show the round-based overview but no event timeline.

3. **Replay map**: The replay screen uses a simplified visualization (event counters + phase indicator) instead of a full Google Maps replay. This avoids API costs during replay. Location events are counted but not plotted on a map.

4. **Admin behind OAuth**: The `/admin` route redirects to Google OAuth via access-manager. Automated tests can only verify the redirect, not the admin UI itself.

## Analyzer Status

- **Phase 2 files**: 0 warnings
- **Pre-existing files**: ~240 info-level hints (trailing commas, const constructors) and a few pre-existing warnings in Phase 1 code. No errors except one pre-existing test file issue (`widget_test.dart` references undefined `MyApp`).
