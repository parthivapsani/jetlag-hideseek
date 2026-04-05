# Jet Lag: Hide & Seek - Self-Hosted Deployment Guide

This document is the complete guide for deploying the Jet Lag Hide & Seek app as a self-hosted PWA on a homeserver. It is written so that a Claude Code session on the homeserver can read it and execute everything from start to finish.

## Architecture Decisions

- **PWA (Flutter Web), not a native app.** No one wants to pay for an Apple Developer account or deal with sideloading. Everyone opens a URL on their phone.
- **Self-hosted Supabase on the homeserver.** Supabase is open-source and runs in Docker. The Flutter code already has full Supabase integration (CRUD, Realtime subscriptions, storage), so self-hosting means zero code changes to the backend layer.
- **Google Maps JavaScript API.** The `google_maps_flutter` package includes `google_maps_flutter_web` which uses the Google Maps JS API automatically when built for web. Same data, same Places API, same everything — just rendered via JS instead of native SDK. The $200/month free credit from Google covers ~1-2k API calls easily.
- **Single concurrent game.** The database schema supports multiple sessions but we only ever run one at a time. No need for multi-tenant optimization.
- **Remove RevenueCat.** The `purchases_flutter` dependency has no code wiring — it's dead weight. Remove it from pubspec.yaml.

## Host Environment

The homeserver runs **Proxmox** with LXC/Docker containers (already running Jellyfin and other services). Deployment uses Docker Compose to run:

1. **Supabase** (PostgreSQL + GoTrue auth + Realtime + Storage + Kong API gateway)
2. **Nginx** (or Caddy) to serve the Flutter web build and reverse-proxy Supabase

## Prerequisites

On the homeserver you need:
- Docker and Docker Compose
- Git
- A domain or local DNS name pointing to the homeserver (e.g., `jetlag.local` or a real domain with HTTPS via Caddy/Let's Encrypt)
- A Google Maps API key (see section below)

You do NOT need:
- Flutter SDK on the server (build the web app on a dev machine or in CI, then copy the build output)
- OR: install Flutter on the server to build there — either approach works

---

## Step-by-Step Deployment

### Step 1: Get a Google Maps API Key

1. Go to https://console.cloud.google.com/
2. Create a new project (or use an existing one)
3. Enable these APIs:
   - **Maps JavaScript API** (required — this is what Flutter web uses)
   - **Places API** (required — used for station/POI search in question drafting)
   - **Geocoding API** (optional — used for reverse geocoding)
4. Go to Credentials > Create Credentials > API Key
5. Restrict the key:
   - Application restriction: **HTTP referrers** — add your domain (e.g., `https://jetlag.yourdomain.com/*`)
   - API restriction: limit to the 3 APIs above
6. Save the key — you'll need it for the Flutter web build

**Cost:** Google gives $200/month free credit. Maps JS API costs ~$7 per 1000 loads, Places API ~$17 per 1000 requests. At 1-2k calls/month total you'll pay $0.

### Step 2: Set Up Self-Hosted Supabase

Supabase provides an official Docker Compose setup.

```bash
# Clone the Supabase repo
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker

# Copy the example env file
cp .env.example .env
```

Edit `.env` and set these values:

```bash
# IMPORTANT: Change these from defaults
POSTGRES_PASSWORD=<generate-a-strong-password>
JWT_SECRET=<generate-a-random-string-at-least-32-chars>
ANON_KEY=<generate-using-jwt-secret>   # See below
SERVICE_ROLE_KEY=<generate-using-jwt-secret>  # See below
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=<your-dashboard-password>

# Set your domain
SITE_URL=https://jetlag.yourdomain.com
API_EXTERNAL_URL=https://jetlag.yourdomain.com/supabase
```

**Generate JWT keys:** Use https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys or:

```bash
# Install jwt-cli or use the Supabase dashboard after first boot
# The anon key needs: role=anon, iss=supabase
# The service key needs: role=service_role, iss=supabase
```

Start Supabase:

```bash
docker compose up -d
```

Supabase Studio (admin dashboard) will be at `http://<server-ip>:8000` by default.

### Step 3: Run Database Migrations

The migration file is in this repo at `supabase/migrations/001_initial_schema.sql`. Apply it:

**Option A — Via Supabase Studio:**
1. Open Studio at `http://<server-ip>:8000`
2. Go to SQL Editor
3. Paste the contents of `supabase/migrations/001_initial_schema.sql`
4. Run it

**Option B — Via psql:**
```bash
# Connect to the Supabase PostgreSQL instance
docker exec -i supabase-db psql -U postgres -d postgres < /path/to/jetlag/supabase/migrations/001_initial_schema.sql
```

### Step 4: Enable Realtime

The migration already adds tables to `supabase_realtime` publication, but verify in Studio:
1. Go to Database > Replication
2. Confirm these tables are in the `supabase_realtime` publication:
   - `sessions`
   - `participants`
   - `session_questions`
   - `hider_cards`
   - `active_curses`

### Step 5: Create Storage Buckets

The app uploads photos and audio to Supabase Storage. Create the buckets:

**Via Studio:** Go to Storage > Create Bucket:
- `question-photos` (public: false)
- `question-audio` (public: false)

**Via SQL:**
```sql
INSERT INTO storage.buckets (id, name, public) VALUES ('question-photos', 'question-photos', false);
INSERT INTO storage.buckets (id, name, public) VALUES ('question-audio', 'question-audio', false);

-- Allow authenticated users to upload
CREATE POLICY "Users can upload photos" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'question-photos');
CREATE POLICY "Users can read photos" ON storage.objects
    FOR SELECT USING (bucket_id = 'question-photos');
CREATE POLICY "Users can upload audio" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'question-audio');
CREATE POLICY "Users can read audio" ON storage.objects
    FOR SELECT USING (bucket_id = 'question-audio');
```

### Step 6: Code Changes Before Building

These changes need to be made to the Flutter codebase before building for web:

#### 6a. Remove RevenueCat dependency

In `pubspec.yaml`, delete:
```yaml
  # Payments (RevenueCat)
  purchases_flutter: ^6.17.0
```

#### 6b. Add Google Maps JS API script to web/index.html

After running `flutter create --platforms=web .` (if the web directory doesn't exist yet), edit `web/index.html` and add this in the `<head>`:

```html
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_GOOGLE_MAPS_API_KEY&libraries=places"></script>
```

Replace `YOUR_GOOGLE_MAPS_API_KEY` with your actual key.

#### 6c. Verify web platform support

Some packages may need web-specific adjustments:
- `google_maps_flutter` — works on web out of the box via `google_maps_flutter_web`
- `geolocator` — needs `geolocator_web` (should be pulled in automatically by the federated plugin)
- `image_picker` — works on web (uses file picker instead of camera)
- `record` (audio) — may not work on web. Audio recording for oddball questions may need to be skipped or use `MediaRecorder` JS interop. This is a nice-to-have, not critical.
- `path_provider` — limited on web (uses browser storage). May need conditional logic.
- `shared_preferences` — works on web (uses localStorage)
- `permission_handler` — not needed on web (browser handles permissions natively). May need to be conditionally imported or stubbed.

#### 6d. Create .env file

```bash
cp .env.example .env
```

Edit `.env`:
```bash
SUPABASE_URL=https://jetlag.yourdomain.com/supabase
SUPABASE_ANON_KEY=<your-generated-anon-key>
GOOGLE_MAPS_API_KEY=<your-google-maps-api-key>
```

### Step 7: Build the Flutter Web App

On a machine with Flutter SDK installed:

```bash
cd /path/to/jetlag

# Ensure web platform is enabled
flutter create --platforms=web .

# Get dependencies
flutter pub get

# Generate Freezed models (if needed)
dart run build_runner build --delete-conflicting-outputs

# Build for web, passing Supabase config as dart-define
flutter build web \
  --web-renderer html \
  --dart-define=SUPABASE_URL=https://jetlag.yourdomain.com/supabase \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

The `--web-renderer html` flag is important — it gives better compatibility with Google Maps on mobile browsers than the default CanvasKit renderer.

The build output will be in `build/web/`.

### Step 8: Serve the Web App

#### Option A: Nginx (if you already have it)

```nginx
server {
    listen 80;
    server_name jetlag.yourdomain.com;

    # Flutter web app
    root /var/www/jetlag/web;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Reverse proxy to Supabase
    location /supabase/ {
        proxy_pass http://localhost:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";  # Required for Realtime WebSockets
    }
}
```

#### Option B: Caddy (simpler, auto-HTTPS)

```
jetlag.yourdomain.com {
    root * /var/www/jetlag/web
    try_files {path} /index.html
    file_server

    handle_path /supabase/* {
        reverse_proxy localhost:8000
    }
}
```

#### Option C: Docker (all-in-one)

Create a `docker-compose.yml` in the repo root:

```yaml
version: '3.8'
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./build/web:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    restart: unless-stopped
```

With `nginx.conf`:
```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

Then Supabase runs as a separate Docker Compose stack (from Step 2).

### Step 9: Copy Build to Server

```bash
# From dev machine
rsync -avz build/web/ user@homeserver:/var/www/jetlag/web/

# Or if using Docker, copy to wherever the volume mount points
scp -r build/web/ user@homeserver:/path/to/jetlag/build/web/
```

### Step 10: Test It

1. Open `https://jetlag.yourdomain.com` on your phone's browser
2. Add to home screen (this makes it a PWA — full screen, app-like)
3. Create a game, have a friend join via room code
4. Verify:
   - Google Maps loads and is interactive
   - Location permissions work (browser will prompt)
   - Real-time updates work between two browsers (open two tabs to test)

---

## Updating the App

When you make code changes:

```bash
# On dev machine
flutter build web --web-renderer html \
  --dart-define=SUPABASE_URL=https://jetlag.yourdomain.com/supabase \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Copy to server
rsync -avz build/web/ user@homeserver:/var/www/jetlag/web/
```

No restart needed — Nginx serves static files, so the next page load picks up changes.

---

## Troubleshooting

### Google Maps not loading
- Check browser console for API key errors
- Verify the Maps JavaScript API is enabled in Google Cloud Console
- Verify your domain is in the API key's HTTP referrer restrictions

### Supabase connection failing
- Check that the `SUPABASE_URL` dart-define matches your actual Supabase URL
- Check that WebSocket connections aren't blocked (the `/supabase/` proxy needs `Upgrade` and `Connection` headers for Realtime)
- Check Supabase logs: `docker compose logs -f`

### Location not working
- Must be served over HTTPS (or localhost) — browsers block geolocation on plain HTTP
- Users need to grant location permission when prompted

### Audio recording not working on web
- The `record` package has limited web support. This is a known limitation.
- For now, oddball questions that need audio can use text input instead.
- Future fix: use `package:web` or JS interop with `MediaRecorder` API.

### PWA not installable
- Needs HTTPS
- Needs a valid `manifest.json` (Flutter generates one in `build/web/`)
- Some browsers need a service worker (Flutter generates one)

---

## Architecture Summary

```
Phone Browser (PWA)
    │
    ├── Flutter Web App (static files from Nginx/Caddy)
    │     ├── Google Maps JS API (renders maps, Places search)
    │     ├── Supabase JS client (auth, database, storage)
    │     └── Browser Geolocation API (player location)
    │
    └── Homeserver
          ├── Nginx/Caddy (serves PWA + reverse proxy)
          └── Supabase (Docker)
                ├── PostgreSQL (game state)
                ├── GoTrue (auth)
                ├── Realtime (WebSocket sync)
                └── Storage (photos/audio)
```

## What's Left to Build

The UI and data layer are largely complete. The main remaining work:

1. **Web compatibility fixes** — Audit all platform-specific code (`permission_handler`, `path_provider`, `record`) and add web fallbacks or conditional imports where needed.
2. **Wire up real-time game sync** — The `RealtimeService` and providers exist but the game views need to subscribe and react to changes. Test with two browser tabs.
3. **Question submission to backend** — The `SupabaseService` has `askQuestion()` and `answerQuestion()` methods. Wire them into the question drafting and answer UI.
4. **Polygon editor polish** — Works but needs UX improvements for touch/mouse on web.
5. **End-to-end multiplayer test** — Create session, join, go through all game phases, verify state syncs.
6. **PWA manifest tuning** — App name, icons, theme color, offline behavior.
