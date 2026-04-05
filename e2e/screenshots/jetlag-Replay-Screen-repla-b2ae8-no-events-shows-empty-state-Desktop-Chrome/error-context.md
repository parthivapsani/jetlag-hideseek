# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: jetlag.spec.ts >> Replay Screen >> replay page with no events shows empty state
- Location: tests/jetlag.spec.ts:480:7

# Error details

```
Test timeout of 60000ms exceeded.
```

```
Error: page.goto: net::ERR_ABORTED; maybe frame was detached?
Call log:
  - navigating to "https://jetlag.ratz.fyi/game/1a5f7224-fc40-47e6-9565-a76a6aa22155/replay", waiting until "load"

```

# Test source

```ts
  383 |   test.beforeAll(async ({ request }) => {
  384 |     testGame = await createTestGame(request);
  385 | 
  386 |     // Create a round
  387 |     const teamsRes = await request.get(`${SUPABASE}/teams?session_id=eq.${testGame.sessionId}&order=display_order`, { headers: HEADERS });
  388 |     const teams = await teamsRes.json();
  389 | 
  390 |     const roundRes = await request.post(`${SUPABASE}/rounds`, {
  391 |       headers: HEADERS,
  392 |       data: {
  393 |         session_id: testGame.sessionId,
  394 |         round_number: 1,
  395 |         hider_team_id: teams[1].id,
  396 |         seeker_team_id: teams[0].id,
  397 |         status: 'found',
  398 |         found_at: new Date().toISOString(),
  399 |         hide_duration_seconds: 1800,
  400 |       },
  401 |     });
  402 |     const round = (await roundRes.json())[0];
  403 |     roundId = round.id;
  404 | 
  405 |     // End session
  406 |     await request.patch(`${SUPABASE}/sessions?id=eq.${testGame.sessionId}`, {
  407 |       headers: HEADERS,
  408 |       data: { status: 'ended', winning_team_id: teams[1].id, ended_at: new Date().toISOString() },
  409 |     });
  410 | 
  411 |     // Create test events
  412 |     await createTestEvents(request, testGame.sessionId, roundId);
  413 |   });
  414 | 
  415 |   test.afterAll(async ({ request }) => {
  416 |     await cleanupTestGame(request, testGame.sessionId, testGame.areaId);
  417 |   });
  418 | 
  419 |   test('summary page loads with events', async ({ page }) => {
  420 |     await page.goto(`${BASE}/game/${testGame.sessionId}/summary`);
  421 |     await page.waitForTimeout(6000);
  422 |     await page.screenshot({ path: 'screenshots/post-game-summary.png', fullPage: true });
  423 | 
  424 |     const content = await page.content();
  425 |     expect(content.length).toBeGreaterThan(1000);
  426 |   });
  427 | 
  428 |   test('game over has View Details button', async ({ page }) => {
  429 |     await page.goto(`${BASE}/game/${testGame.sessionId}/over`);
  430 |     await page.waitForTimeout(6000);
  431 |     await page.screenshot({ path: 'screenshots/game-over-with-details.png', fullPage: true });
  432 |   });
  433 | });
  434 | 
  435 | test.describe('Replay Screen', () => {
  436 |   let testGame: { sessionId: string; roomCode: string; areaId: string };
  437 | 
  438 |   test.beforeAll(async ({ request }) => {
  439 |     testGame = await createTestGame(request);
  440 | 
  441 |     // Create round + events
  442 |     const teamsRes = await request.get(`${SUPABASE}/teams?session_id=eq.${testGame.sessionId}&order=display_order`, { headers: HEADERS });
  443 |     const teams = await teamsRes.json();
  444 | 
  445 |     const roundRes = await request.post(`${SUPABASE}/rounds`, {
  446 |       headers: HEADERS,
  447 |       data: {
  448 |         session_id: testGame.sessionId,
  449 |         round_number: 1,
  450 |         hider_team_id: teams[1].id,
  451 |         seeker_team_id: teams[0].id,
  452 |         status: 'found',
  453 |         found_at: new Date().toISOString(),
  454 |         hide_duration_seconds: 2400,
  455 |       },
  456 |     });
  457 |     const round = (await roundRes.json())[0];
  458 | 
  459 |     await createTestEvents(request, testGame.sessionId, round.id);
  460 | 
  461 |     await request.patch(`${SUPABASE}/sessions?id=eq.${testGame.sessionId}`, {
  462 |       headers: HEADERS,
  463 |       data: { status: 'ended', ended_at: new Date().toISOString() },
  464 |     });
  465 |   });
  466 | 
  467 |   test.afterAll(async ({ request }) => {
  468 |     await cleanupTestGame(request, testGame.sessionId, testGame.areaId);
  469 |   });
  470 | 
  471 |   test('replay page loads with events and scrubber', async ({ page }) => {
  472 |     await page.goto(`${BASE}/game/${testGame.sessionId}/replay`);
  473 |     await page.waitForTimeout(6000);
  474 |     await page.screenshot({ path: 'screenshots/replay.png', fullPage: true });
  475 | 
  476 |     const content = await page.content();
  477 |     expect(content.length).toBeGreaterThan(1000);
  478 |   });
  479 | 
  480 |   test('replay page with no events shows empty state', async ({ page, request }) => {
  481 |     // Create a game with no events
  482 |     const emptyGame = await createTestGame(request);
> 483 |     await page.goto(`${BASE}/game/${emptyGame.sessionId}/replay`);
      |                ^ Error: page.goto: net::ERR_ABORTED; maybe frame was detached?
  484 |     await page.waitForTimeout(6000);
  485 |     await page.screenshot({ path: 'screenshots/replay-empty.png', fullPage: true });
  486 |     await cleanupTestGame(request, emptyGame.sessionId, emptyGame.areaId);
  487 |   });
  488 | });
  489 | 
  490 | test.describe('Event Logging via API', () => {
  491 |   test('game_events table accepts inserts', async ({ request }) => {
  492 |     const testGame = await createTestGame(request);
  493 | 
  494 |     // Insert an event
  495 |     const res = await request.post(`${SUPABASE}/game_events`, {
  496 |       headers: HEADERS,
  497 |       data: {
  498 |         session_id: testGame.sessionId,
  499 |         event_type: 'phase_change',
  500 |         payload: { phase: 'hiding' },
  501 |       },
  502 |     });
  503 |     expect(res.status()).toBe(201);
  504 | 
  505 |     // Read it back
  506 |     const getRes = await request.get(`${SUPABASE}/game_events?session_id=eq.${testGame.sessionId}`, { headers: HEADERS });
  507 |     const events = await getRes.json();
  508 |     expect(events.length).toBeGreaterThan(0);
  509 |     expect(events[0].event_type).toBe('phase_change');
  510 | 
  511 |     await cleanupTestGame(request, testGame.sessionId, testGame.areaId);
  512 |   });
  513 | });
  514 | 
  515 | test.describe('API Usage Tracking', () => {
  516 |   test('api_usage table accepts inserts', async ({ request }) => {
  517 |     // Insert a usage record
  518 |     const res = await request.post(`${SUPABASE}/api_usage`, {
  519 |       headers: HEADERS,
  520 |       data: {
  521 |         api_type: 'map_load',
  522 |         estimated_cost_cents: 700,
  523 |       },
  524 |     });
  525 |     expect(res.status()).toBe(201);
  526 | 
  527 |     // Read it back
  528 |     const getRes = await request.get(`${SUPABASE}/api_usage?api_type=eq.map_load&order=created_at.desc&limit=1`, { headers: HEADERS });
  529 |     const usage = await getRes.json();
  530 |     expect(usage.length).toBeGreaterThan(0);
  531 |     expect(usage[0].estimated_cost_cents).toBe(700);
  532 | 
  533 |     // Cleanup
  534 |     await request.delete(`${SUPABASE}/api_usage?id=eq.${usage[0].id}`, { headers: HEADERS });
  535 |   });
  536 | });
  537 | 
  538 | test.describe('Page Transitions', () => {
  539 |   test('pages load with slide transitions', async ({ page }) => {
  540 |     await page.goto(BASE);
  541 |     await page.waitForTimeout(4000);
  542 | 
  543 |     // Navigate to ideas
  544 |     await page.goto(`${BASE}/ideas`);
  545 |     await page.waitForTimeout(3000);
  546 |     await page.screenshot({ path: 'screenshots/ideas-transition.png', fullPage: true });
  547 | 
  548 |     // Navigate to settings
  549 |     await page.goto(`${BASE}/settings`);
  550 |     await page.waitForTimeout(3000);
  551 |     await page.screenshot({ path: 'screenshots/settings-transition.png', fullPage: true });
  552 |   });
  553 | });
  554 | 
  555 | test.describe('Network & Performance', () => {
  556 |   test('no console errors on home page', async ({ page }) => {
  557 |     const errors: string[] = [];
  558 |     page.on('console', msg => {
  559 |       if (msg.type() === 'error') errors.push(msg.text());
  560 |     });
  561 | 
  562 |     await page.goto(BASE);
  563 |     await page.waitForTimeout(5000);
  564 | 
  565 |     // Filter out known non-issues (Google Maps warnings, etc.)
  566 |     const realErrors = errors.filter(e =>
  567 |       !e.includes('google') &&
  568 |       !e.includes('Maps') &&
  569 |       !e.includes('favicon') &&
  570 |       !e.includes('manifest')
  571 |     );
  572 | 
  573 |     if (realErrors.length > 0) {
  574 |       console.log('Console errors found:', realErrors);
  575 |     }
  576 |     // Log but don't fail — Flutter may have benign console output
  577 |   });
  578 | 
  579 |   test('critical assets load', async ({ page }) => {
  580 |     const failedRequests: string[] = [];
  581 |     page.on('requestfailed', req => {
  582 |       failedRequests.push(`${req.url()} - ${req.failure()?.errorText}`);
  583 |     });
```