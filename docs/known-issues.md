# Smoke Test Results & Known Issues

**Date:** 2026-04-05
**Tested by:** Automated curl smoke test (no browser)

## What Works

- **Site loads correctly** — HTML includes Flutter bootstrap (`flutter_bootstrap.js`), Plus Jakarta Sans font, and Google Maps script
- **Flutter assets served** — `flutter.js`, `main.dart.js`, and `manifest.json` all return HTTP 200
- **Supabase proxy** — `/supabase/rest/v1/` returns the full PostgREST Swagger/OpenAPI spec via Kong gateway
- **Feature requests table** — INSERT and SELECT both work; row inserted with auto-generated UUID and timestamps
- **Teams table** — Accessible, returns empty array (no teams created yet)
- **Rounds table** — Accessible, returns empty array (no rounds created yet)
- **SPA routing** — `/ideas`, `/settings`, and `/join` all return HTTP 200 (Caddy serves index.html for all routes)

## What Needs Browser Testing

These cannot be verified via curl and require manual browser testing:

- Flutter app actually renders (WebAssembly/CanvasKit initialization)
- Google Maps loads and displays correctly with the configured API key
- Real-time Supabase subscriptions (WebSocket connections)
- Game session creation and join flow
- Team assignment and round management UI
- GPS/location tracking functionality
- PWA install prompt and offline behavior
- Responsive layout on mobile devices

## Known Issues

- None found during smoke testing. All endpoints respond correctly.

## Compilation Warnings

- No build-time warnings observed during this test (build was done in a prior task).
