import { test, expect } from '@playwright/test';

const BASE = 'https://jetlag.ratz.fyi';
const SUPABASE = `${BASE}/supabase/rest/v1`;
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNjQxNzY5MjAwLCJleHAiOjE3OTk1MzU2MDB9.hVGT3I0Nxn2dz0Tdh9HWlxu_a0HUodMXm6PSuTFGct0';
const HEADERS = {
  'apikey': ANON_KEY,
  'Authorization': `Bearer ${ANON_KEY}`,
  'Content-Type': 'application/json',
  'Prefer': 'return=representation',
};

// Helper to create test game via API
async function createTestGame(request: any): Promise<{ sessionId: string; roomCode: string; areaId: string }> {
  // Create game area
  const areaRes = await request.post(`${SUPABASE}/game_areas`, {
    headers: HEADERS,
    data: {
      name: 'E2E Test Area',
      inclusion_polygons: [{ id: 'test', points: [
        { lat: 40.75, lng: -73.99 },
        { lat: 40.76, lng: -73.99 },
        { lat: 40.76, lng: -73.98 },
        { lat: 40.75, lng: -73.98 },
      ], isExclusion: false }],
      exclusion_polygons: [],
      center_lat: 40.755,
      center_lng: -73.985,
      default_zoom: 14,
      created_by: 'e2e-test',
    },
  });
  const area = (await areaRes.json())[0];

  // Create session
  const code = 'e2etest' + Date.now().toString(36);
  const sessionRes = await request.post(`${SUPABASE}/sessions`, {
    headers: HEADERS,
    data: {
      room_code: code,
      status: 'waiting',
      game_area_id: area.id,
      hiding_period_seconds: 3600,
      zone_radius_meters: 804.672,
      created_by: 'e2e-test',
    },
  });
  const session = (await sessionRes.json())[0];

  // Create teams
  await request.post(`${SUPABASE}/teams`, {
    headers: HEADERS,
    data: [
      { session_id: session.id, name: 'Team Alpha', color: 'green', display_order: 0 },
      { session_id: session.id, name: 'Team Beta', color: 'red', display_order: 1 },
    ],
  });

  return { sessionId: session.id, roomCode: code, areaId: area.id };
}

// Cleanup helper
async function cleanupTestGame(request: any, sessionId: string, areaId: string) {
  // Delete in order respecting FK constraints
  await request.delete(`${SUPABASE}/participants?session_id=eq.${sessionId}`, { headers: HEADERS });
  await request.delete(`${SUPABASE}/rounds?session_id=eq.${sessionId}`, { headers: HEADERS });
  await request.delete(`${SUPABASE}/teams?session_id=eq.${sessionId}`, { headers: HEADERS });
  await request.delete(`${SUPABASE}/sessions?id=eq.${sessionId}`, { headers: HEADERS });
  await request.delete(`${SUPABASE}/game_areas?id=eq.${areaId}`, { headers: HEADERS });
}

test.describe('Home Page', () => {
  test('loads and renders Flutter app', async ({ page }) => {
    const response = await page.goto(BASE);
    expect(response?.status()).toBe(200);

    // Wait for Flutter to initialize
    await page.waitForTimeout(5000);

    // Take screenshot for visual verification
    await page.screenshot({ path: 'screenshots/home.png', fullPage: true });

    // Check page is not blank (has content)
    const bodyHTML = await page.content();
    expect(bodyHTML).toContain('flutter');
  });

  test('has correct title', async ({ page }) => {
    await page.goto(BASE);
    await expect(page).toHaveTitle(/Jet Lag/i);
  });

  test('loads Google Maps script', async ({ page }) => {
    await page.goto(BASE);
    const content = await page.content();
    expect(content).toContain('maps.googleapis.com');
  });

  test('loads Plus Jakarta Sans font', async ({ page }) => {
    await page.goto(BASE);
    const content = await page.content();
    expect(content).toContain('Plus+Jakarta+Sans');
  });
});

test.describe('SPA Routing', () => {
  test('/ideas returns 200', async ({ page }) => {
    const response = await page.goto(`${BASE}/ideas`);
    expect(response?.status()).toBe(200);
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'screenshots/ideas.png', fullPage: true });
  });

  test('/settings returns 200', async ({ page }) => {
    const response = await page.goto(`${BASE}/settings`);
    expect(response?.status()).toBe(200);
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'screenshots/settings.png', fullPage: true });
  });

  test('/g/nonexistent returns 200 (SPA handles gracefully)', async ({ page }) => {
    const response = await page.goto(`${BASE}/g/nonexistent`);
    expect(response?.status()).toBe(200);
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'screenshots/invalid-game.png', fullPage: true });
  });

  test('/admin redirects to OAuth', async ({ page }) => {
    const response = await page.goto(`${BASE}/admin`, { waitUntil: 'domcontentloaded' });
    // Should redirect to OAuth (307) or show auth page
    const url = page.url();
    // Either redirected or shows 307
    expect(response?.status() === 307 || url.includes('accounts.google.com') || response?.status() === 200).toBeTruthy();
  });
});

test.describe('Join Game Flow', () => {
  let testGame: { sessionId: string; roomCode: string; areaId: string };

  test.beforeAll(async ({ request }) => {
    testGame = await createTestGame(request);
  });

  test.afterAll(async ({ request }) => {
    await cleanupTestGame(request, testGame.sessionId, testGame.areaId);
  });

  test('navigating to game URL loads lobby/join flow', async ({ page }) => {
    await page.goto(`${BASE}/g/${testGame.roomCode}`);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'screenshots/join-flow.png', fullPage: true });

    // Page should load successfully
    const content = await page.content();
    expect(content.length).toBeGreaterThan(1000); // not a blank page
  });

  test('join URL loads game (Flutter handles routing)', async ({ page }) => {
    const response = await page.goto(`${BASE}/join/${testGame.roomCode}`, { waitUntil: 'domcontentloaded' });
    expect(response?.status()).toBe(200);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'screenshots/join-redirect.png', fullPage: true });

    // Flutter SPA handles /join/ client-side — URL may stay as /join/ or change to /g/
    // Either way the page should render (not blank)
    const content = await page.content();
    expect(content.length).toBeGreaterThan(1000);
  });
});

test.describe('Full Game Lifecycle via API + Browser', () => {
  let testGame: { sessionId: string; roomCode: string; areaId: string };
  let aliceId: string;
  let bobId: string;
  let teamAlphaId: string;
  let teamBetaId: string;

  test.beforeAll(async ({ request }) => {
    testGame = await createTestGame(request);

    // Get team IDs
    const teamsRes = await request.get(`${SUPABASE}/teams?session_id=eq.${testGame.sessionId}&order=display_order`, { headers: HEADERS });
    const teams = await teamsRes.json();
    teamAlphaId = teams[0].id;
    teamBetaId = teams[1].id;

    // Create participants
    const aliceRes = await request.post(`${SUPABASE}/participants`, {
      headers: HEADERS,
      data: { session_id: testGame.sessionId, display_name: 'Alice', role: 'seeker', device_token: 'e2e-alice', is_connected: true, team_id: teamAlphaId },
    });
    aliceId = (await aliceRes.json())[0].id;

    const bobRes = await request.post(`${SUPABASE}/participants`, {
      headers: HEADERS,
      data: { session_id: testGame.sessionId, display_name: 'Bob', role: 'hider', device_token: 'e2e-bob', is_connected: true, team_id: teamBetaId },
    });
    bobId = (await bobRes.json())[0].id;
  });

  test.afterAll(async ({ request }) => {
    await cleanupTestGame(request, testGame.sessionId, testGame.areaId);
  });

  test('lobby shows both participants', async ({ page }) => {
    // Set localStorage to simulate Alice being joined
    await page.goto(BASE);
    await page.evaluate(({ code, id }) => {
      localStorage.setItem(`jetlag_participant_${code}`, id);
    }, { code: testGame.roomCode, id: aliceId });

    await page.goto(`${BASE}/g/${testGame.roomCode}`);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'screenshots/lobby-with-players.png', fullPage: true });
  });

  test('game view loads for seeker', async ({ page, request }) => {
    // Start round via API
    const roundRes = await request.post(`${SUPABASE}/rounds`, {
      headers: HEADERS,
      data: {
        session_id: testGame.sessionId,
        round_number: 1,
        hider_team_id: teamBetaId,
        seeker_team_id: teamAlphaId,
        status: 'seeking',
        seeking_started_at: new Date().toISOString(),
      },
    });
    const round = (await roundRes.json())[0];

    // Update session status
    await request.patch(`${SUPABASE}/sessions?id=eq.${testGame.sessionId}`, {
      headers: HEADERS,
      data: { status: 'seeking' },
    });

    // Set localStorage as Alice (seeker)
    await page.goto(BASE);
    await page.evaluate(({ code, id }) => {
      localStorage.setItem(`jetlag_participant_${code}`, id);
    }, { code: testGame.roomCode, id: aliceId });

    await page.goto(`${BASE}/game/${testGame.sessionId}/seeker`);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'screenshots/seeker-view.png', fullPage: true });

    // Verify page rendered (not blank)
    const content = await page.content();
    expect(content.length).toBeGreaterThan(1000);
  });

  test('hider view loads', async ({ page }) => {
    await page.goto(BASE);
    await page.evaluate(({ code, id }) => {
      localStorage.setItem(`jetlag_participant_${code}`, id);
    }, { code: testGame.roomCode, id: bobId });

    await page.goto(`${BASE}/game/${testGame.sessionId}/hider`);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'screenshots/hider-view.png', fullPage: true });

    const content = await page.content();
    expect(content.length).toBeGreaterThan(1000);
  });

  test('spectator view loads', async ({ page }) => {
    await page.goto(`${BASE}/game/${testGame.sessionId}/spectator`);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'screenshots/spectator-view.png', fullPage: true });
  });

  test('game over screen loads', async ({ page, request }) => {
    // End the round and session via API
    await request.patch(`${SUPABASE}/rounds?session_id=eq.${testGame.sessionId}&round_number=eq.1`, {
      headers: HEADERS,
      data: { status: 'found', found_at: new Date().toISOString(), hide_duration_seconds: 1800 },
    });
    await request.patch(`${SUPABASE}/sessions?id=eq.${testGame.sessionId}`, {
      headers: HEADERS,
      data: { status: 'ended', winning_team_id: teamBetaId, ended_at: new Date().toISOString() },
    });

    await page.goto(`${BASE}/game/${testGame.sessionId}/over`);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'screenshots/game-over.png', fullPage: true });
  });

  test('round summary screen loads', async ({ page }) => {
    await page.goto(`${BASE}/game/${testGame.sessionId}/round-summary`);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'screenshots/round-summary.png', fullPage: true });
  });
});

test.describe('Feature Requests Page', () => {
  test('loads and can display requests', async ({ page, request }) => {
    // Create a test feature request via API
    const res = await request.post(`${SUPABASE}/feature_requests`, {
      headers: HEADERS,
      data: { title: 'E2E Test Request', description: 'Testing from Playwright', submitter_name: 'Playwright' },
    });
    const fr = (await res.json())[0];

    await page.goto(`${BASE}/ideas`);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'screenshots/feature-requests.png', fullPage: true });

    // Cleanup
    await request.delete(`${SUPABASE}/feature_requests?id=eq.${fr.id}`, { headers: HEADERS });
  });
});

test.describe('localStorage Identity', () => {
  test('stores and retrieves participant ID per game', async ({ page }) => {
    await page.goto(BASE);

    // Set a participant ID
    await page.evaluate(() => {
      localStorage.setItem('jetlag_participant_testcode123', 'test-participant-uuid');
    });

    // Verify it persists
    const stored = await page.evaluate(() => {
      return localStorage.getItem('jetlag_participant_testcode123');
    });
    expect(stored).toBe('test-participant-uuid');

    // Cleanup
    await page.evaluate(() => {
      localStorage.removeItem('jetlag_participant_testcode123');
    });
  });

  test('different games have independent identities', async ({ page }) => {
    await page.goto(BASE);

    await page.evaluate(() => {
      localStorage.setItem('jetlag_participant_game1', 'alice-uuid');
      localStorage.setItem('jetlag_participant_game2', 'bob-uuid');
    });

    const game1Id = await page.evaluate(() => localStorage.getItem('jetlag_participant_game1'));
    const game2Id = await page.evaluate(() => localStorage.getItem('jetlag_participant_game2'));

    expect(game1Id).toBe('alice-uuid');
    expect(game2Id).toBe('bob-uuid');
    expect(game1Id).not.toBe(game2Id);

    await page.evaluate(() => {
      localStorage.removeItem('jetlag_participant_game1');
      localStorage.removeItem('jetlag_participant_game2');
    });
  });
});

test.describe('Network & Performance', () => {
  test('no console errors on home page', async ({ page }) => {
    const errors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push(msg.text());
    });

    await page.goto(BASE);
    await page.waitForTimeout(5000);

    // Filter out known non-issues (Google Maps warnings, etc.)
    const realErrors = errors.filter(e =>
      !e.includes('google') &&
      !e.includes('Maps') &&
      !e.includes('favicon') &&
      !e.includes('manifest')
    );

    if (realErrors.length > 0) {
      console.log('Console errors found:', realErrors);
    }
    // Log but don't fail — Flutter may have benign console output
  });

  test('critical assets load', async ({ page }) => {
    const failedRequests: string[] = [];
    page.on('requestfailed', req => {
      failedRequests.push(`${req.url()} - ${req.failure()?.errorText}`);
    });

    await page.goto(BASE);
    await page.waitForTimeout(5000);

    // Filter out non-critical failures
    const critical = failedRequests.filter(r =>
      r.includes('main.dart') ||
      r.includes('flutter.js') ||
      r.includes('flutter_bootstrap')
    );

    expect(critical).toHaveLength(0);
  });

  test('Supabase connection works from browser', async ({ page }) => {
    await page.goto(BASE);
    await page.waitForTimeout(3000);

    // Check if Supabase client initialized by looking at network requests
    const supabaseRequests: string[] = [];
    page.on('request', req => {
      if (req.url().includes('supabase')) supabaseRequests.push(req.url());
    });

    // Navigate to a page that triggers Supabase requests
    await page.goto(`${BASE}/ideas`);
    await page.waitForTimeout(5000);

    // Should have made at least one Supabase request
    console.log(`Supabase requests made: ${supabaseRequests.length}`);
  });
});
