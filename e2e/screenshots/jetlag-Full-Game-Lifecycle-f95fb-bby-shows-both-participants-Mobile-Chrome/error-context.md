# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: jetlag.spec.ts >> Full Game Lifecycle via API + Browser >> lobby shows both participants
- Location: tests/jetlag.spec.ts:205:7

# Error details

```
Test timeout of 60000ms exceeded.
```

```
Error: page.goto: net::ERR_ABORTED; maybe frame was detached?
Call log:
  - navigating to "https://jetlag.ratz.fyi/", waiting until "load"

```

# Test source

```ts
  107 |   test('/ideas returns 200', async ({ page }) => {
  108 |     const response = await page.goto(`${BASE}/ideas`);
  109 |     expect(response?.status()).toBe(200);
  110 |     await page.waitForTimeout(3000);
  111 |     await page.screenshot({ path: 'screenshots/ideas.png', fullPage: true });
  112 |   });
  113 | 
  114 |   test('/settings returns 200', async ({ page }) => {
  115 |     const response = await page.goto(`${BASE}/settings`);
  116 |     expect(response?.status()).toBe(200);
  117 |     await page.waitForTimeout(3000);
  118 |     await page.screenshot({ path: 'screenshots/settings.png', fullPage: true });
  119 |   });
  120 | 
  121 |   test('/g/nonexistent returns 200 (SPA handles gracefully)', async ({ page }) => {
  122 |     const response = await page.goto(`${BASE}/g/nonexistent`);
  123 |     expect(response?.status()).toBe(200);
  124 |     await page.waitForTimeout(3000);
  125 |     await page.screenshot({ path: 'screenshots/invalid-game.png', fullPage: true });
  126 |   });
  127 | 
  128 |   test('/admin redirects to OAuth', async ({ page }) => {
  129 |     const response = await page.goto(`${BASE}/admin`, { waitUntil: 'domcontentloaded' });
  130 |     // Should redirect to OAuth (307) or show auth page
  131 |     const url = page.url();
  132 |     // Either redirected or shows 307
  133 |     expect(response?.status() === 307 || url.includes('accounts.google.com') || response?.status() === 200).toBeTruthy();
  134 |   });
  135 | });
  136 | 
  137 | test.describe('Join Game Flow', () => {
  138 |   let testGame: { sessionId: string; roomCode: string; areaId: string };
  139 | 
  140 |   test.beforeAll(async ({ request }) => {
  141 |     testGame = await createTestGame(request);
  142 |   });
  143 | 
  144 |   test.afterAll(async ({ request }) => {
  145 |     await cleanupTestGame(request, testGame.sessionId, testGame.areaId);
  146 |   });
  147 | 
  148 |   test('navigating to game URL loads lobby/join flow', async ({ page }) => {
  149 |     await page.goto(`${BASE}/g/${testGame.roomCode}`);
  150 |     await page.waitForTimeout(5000);
  151 |     await page.screenshot({ path: 'screenshots/join-flow.png', fullPage: true });
  152 | 
  153 |     // Page should load successfully
  154 |     const content = await page.content();
  155 |     expect(content.length).toBeGreaterThan(1000); // not a blank page
  156 |   });
  157 | 
  158 |   test('join URL loads game (Flutter handles routing)', async ({ page }) => {
  159 |     const response = await page.goto(`${BASE}/join/${testGame.roomCode}`, { waitUntil: 'domcontentloaded' });
  160 |     expect(response?.status()).toBe(200);
  161 |     await page.waitForTimeout(5000);
  162 |     await page.screenshot({ path: 'screenshots/join-redirect.png', fullPage: true });
  163 | 
  164 |     // Flutter SPA handles /join/ client-side — URL may stay as /join/ or change to /g/
  165 |     // Either way the page should render (not blank)
  166 |     const content = await page.content();
  167 |     expect(content.length).toBeGreaterThan(1000);
  168 |   });
  169 | });
  170 | 
  171 | test.describe('Full Game Lifecycle via API + Browser', () => {
  172 |   let testGame: { sessionId: string; roomCode: string; areaId: string };
  173 |   let aliceId: string;
  174 |   let bobId: string;
  175 |   let teamAlphaId: string;
  176 |   let teamBetaId: string;
  177 | 
  178 |   test.beforeAll(async ({ request }) => {
  179 |     testGame = await createTestGame(request);
  180 | 
  181 |     // Get team IDs
  182 |     const teamsRes = await request.get(`${SUPABASE}/teams?session_id=eq.${testGame.sessionId}&order=display_order`, { headers: HEADERS });
  183 |     const teams = await teamsRes.json();
  184 |     teamAlphaId = teams[0].id;
  185 |     teamBetaId = teams[1].id;
  186 | 
  187 |     // Create participants
  188 |     const aliceRes = await request.post(`${SUPABASE}/participants`, {
  189 |       headers: HEADERS,
  190 |       data: { session_id: testGame.sessionId, display_name: 'Alice', role: 'seeker', device_token: 'e2e-alice', is_connected: true, team_id: teamAlphaId },
  191 |     });
  192 |     aliceId = (await aliceRes.json())[0].id;
  193 | 
  194 |     const bobRes = await request.post(`${SUPABASE}/participants`, {
  195 |       headers: HEADERS,
  196 |       data: { session_id: testGame.sessionId, display_name: 'Bob', role: 'hider', device_token: 'e2e-bob', is_connected: true, team_id: teamBetaId },
  197 |     });
  198 |     bobId = (await bobRes.json())[0].id;
  199 |   });
  200 | 
  201 |   test.afterAll(async ({ request }) => {
  202 |     await cleanupTestGame(request, testGame.sessionId, testGame.areaId);
  203 |   });
  204 | 
  205 |   test('lobby shows both participants', async ({ page }) => {
  206 |     // Set localStorage to simulate Alice being joined
> 207 |     await page.goto(BASE);
      |                ^ Error: page.goto: net::ERR_ABORTED; maybe frame was detached?
  208 |     await page.evaluate(({ code, id }) => {
  209 |       localStorage.setItem(`jetlag_participant_${code}`, id);
  210 |     }, { code: testGame.roomCode, id: aliceId });
  211 | 
  212 |     await page.goto(`${BASE}/g/${testGame.roomCode}`);
  213 |     await page.waitForTimeout(5000);
  214 |     await page.screenshot({ path: 'screenshots/lobby-with-players.png', fullPage: true });
  215 |   });
  216 | 
  217 |   test('game view loads for seeker', async ({ page, request }) => {
  218 |     // Start round via API
  219 |     const roundRes = await request.post(`${SUPABASE}/rounds`, {
  220 |       headers: HEADERS,
  221 |       data: {
  222 |         session_id: testGame.sessionId,
  223 |         round_number: 1,
  224 |         hider_team_id: teamBetaId,
  225 |         seeker_team_id: teamAlphaId,
  226 |         status: 'seeking',
  227 |         seeking_started_at: new Date().toISOString(),
  228 |       },
  229 |     });
  230 |     const round = (await roundRes.json())[0];
  231 | 
  232 |     // Update session status
  233 |     await request.patch(`${SUPABASE}/sessions?id=eq.${testGame.sessionId}`, {
  234 |       headers: HEADERS,
  235 |       data: { status: 'seeking' },
  236 |     });
  237 | 
  238 |     // Set localStorage as Alice (seeker)
  239 |     await page.goto(BASE);
  240 |     await page.evaluate(({ code, id }) => {
  241 |       localStorage.setItem(`jetlag_participant_${code}`, id);
  242 |     }, { code: testGame.roomCode, id: aliceId });
  243 | 
  244 |     await page.goto(`${BASE}/game/${testGame.sessionId}/seeker`);
  245 |     await page.waitForTimeout(5000);
  246 |     await page.screenshot({ path: 'screenshots/seeker-view.png', fullPage: true });
  247 | 
  248 |     // Verify page rendered (not blank)
  249 |     const content = await page.content();
  250 |     expect(content.length).toBeGreaterThan(1000);
  251 |   });
  252 | 
  253 |   test('hider view loads', async ({ page }) => {
  254 |     await page.goto(BASE);
  255 |     await page.evaluate(({ code, id }) => {
  256 |       localStorage.setItem(`jetlag_participant_${code}`, id);
  257 |     }, { code: testGame.roomCode, id: bobId });
  258 | 
  259 |     await page.goto(`${BASE}/game/${testGame.sessionId}/hider`);
  260 |     await page.waitForTimeout(5000);
  261 |     await page.screenshot({ path: 'screenshots/hider-view.png', fullPage: true });
  262 | 
  263 |     const content = await page.content();
  264 |     expect(content.length).toBeGreaterThan(1000);
  265 |   });
  266 | 
  267 |   test('spectator view loads', async ({ page }) => {
  268 |     await page.goto(`${BASE}/game/${testGame.sessionId}/spectator`);
  269 |     await page.waitForTimeout(5000);
  270 |     await page.screenshot({ path: 'screenshots/spectator-view.png', fullPage: true });
  271 |   });
  272 | 
  273 |   test('game over screen loads', async ({ page, request }) => {
  274 |     // End the round and session via API
  275 |     await request.patch(`${SUPABASE}/rounds?session_id=eq.${testGame.sessionId}&round_number=eq.1`, {
  276 |       headers: HEADERS,
  277 |       data: { status: 'found', found_at: new Date().toISOString(), hide_duration_seconds: 1800 },
  278 |     });
  279 |     await request.patch(`${SUPABASE}/sessions?id=eq.${testGame.sessionId}`, {
  280 |       headers: HEADERS,
  281 |       data: { status: 'ended', winning_team_id: teamBetaId, ended_at: new Date().toISOString() },
  282 |     });
  283 | 
  284 |     await page.goto(`${BASE}/game/${testGame.sessionId}/over`);
  285 |     await page.waitForTimeout(5000);
  286 |     await page.screenshot({ path: 'screenshots/game-over.png', fullPage: true });
  287 |   });
  288 | 
  289 |   test('round summary screen loads', async ({ page }) => {
  290 |     await page.goto(`${BASE}/game/${testGame.sessionId}/round-summary`);
  291 |     await page.waitForTimeout(5000);
  292 |     await page.screenshot({ path: 'screenshots/round-summary.png', fullPage: true });
  293 |   });
  294 | });
  295 | 
  296 | test.describe('Feature Requests Page', () => {
  297 |   test('loads and can display requests', async ({ page, request }) => {
  298 |     // Create a test feature request via API
  299 |     const res = await request.post(`${SUPABASE}/feature_requests`, {
  300 |       headers: HEADERS,
  301 |       data: { title: 'E2E Test Request', description: 'Testing from Playwright', submitter_name: 'Playwright' },
  302 |     });
  303 |     const fr = (await res.json())[0];
  304 | 
  305 |     await page.goto(`${BASE}/ideas`);
  306 |     await page.waitForTimeout(5000);
  307 |     await page.screenshot({ path: 'screenshots/feature-requests.png', fullPage: true });
```