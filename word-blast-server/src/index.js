// ============================================================================
// Word Blast API — Cloudflare Worker
// Phase 4/5 + Country/Flag Support + Offline Games + Word Vault
// ============================================================================

const RULESET_VERSION = 'ranked_v1';
const DICTIONARY_VERSION = 'english_v1';
const GENERATOR_VERSION = '1';

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return optionsResponse();
    }

    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    try {
      if (path === '/' || path === '/health') {
        return json({ status: 'ok', service: 'word-blast-api' });
      }
      if (path === '/v1/ranked/start' && method === 'POST') {
        return await handleRankedStart(request, env);
      }
      if (path === '/v1/ranked/finish' && method === 'POST') {
        return await handleRankedFinish(request, env);
      }
      if (path === '/v1/leaderboard/global' && method === 'GET') {
        return await handleLeaderboardGlobal(env, url);
      }
      if (path === '/v1/leaderboard/me' && method === 'GET') {
        return await handleLeaderboardMe(env, url);
      }
      if (path === '/v1/vault' && method === 'GET') {
        return await handleVault(env, url);
      }
      return json({ error: 'not_found' }, 404);
    } catch (err) {
      return json({ error: 'internal', message: String(err) }, 500);
    }
  },
};

// ----------------------------------------------------------------------------
// POST /v1/ranked/start
// ----------------------------------------------------------------------------
async function handleRankedStart(request, env) {
  const body = await readJson(request);
  const playerId = body?.player_id;
  if (!playerId || typeof playerId !== 'string') {
    return json({ error: 'missing_player_id' }, 400);
  }

  const countryRaw = typeof body?.country === 'string' ? body.country.toUpperCase().trim() : '';
  const country = /^[A-Z]{2}$/.test(countryRaw) ? countryRaw : '';

  const now = Date.now();
  const gameId = crypto.randomUUID();
  const seed = randomSeed();

  await env.DB.prepare(`
    INSERT INTO players (id, display_name, country, created_at, last_seen_at)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET 
      last_seen_at = excluded.last_seen_at,
      display_name = excluded.display_name,
      country = excluded.country
  `).bind(playerId, String(body.display_name || 'Player'), country, now, now).run();

  await env.DB.prepare(`
    INSERT INTO games
      (id, player_id, seed, ruleset_version, dictionary_version, generator_version, started_at, status)
    VALUES (?, ?, ?, ?, ?, ?, ?, 'STARTED')
  `).bind(gameId, playerId, seed, RULESET_VERSION, DICTIONARY_VERSION, GENERATOR_VERSION, now).run();

  return json({
    game_id: gameId,
    seed,
    ruleset_version: RULESET_VERSION,
    dictionary_version: DICTIONARY_VERSION,
  });
}

// ----------------------------------------------------------------------------
// POST /v1/ranked/finish
// ----------------------------------------------------------------------------
async function handleRankedFinish(request, env) {
  const body = await readJson(request);
  const { game_id, player_id, score, events, seed, ruleset_version } = body;

  if (!game_id || !player_id) {
    return json({ error: 'missing_fields' }, 400);
  }
  if (typeof score !== 'number' || !Number.isInteger(score) || score < 0) {
    return json({ error: 'invalid_score' }, 400);
  }

  let game = await env.DB.prepare(`SELECT * FROM games WHERE id = ?`).bind(game_id).first();

  // OFFLINE START FALLBACK: The game wasn't registered via /start.
  if (!game) {
    if (typeof seed !== 'number' || !ruleset_version) {
      return json({ error: 'missing_offline_game_data' }, 400);
    }
    const nowStart = Date.now();
    await env.DB.prepare(`
      INSERT INTO games (id, player_id, seed, ruleset_version, dictionary_version, generator_version, started_at, status, started_offline)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'STARTED', 1)
    `).bind(game_id, player_id, seed, ruleset_version, DICTIONARY_VERSION, GENERATOR_VERSION, nowStart).run();
    
    game = await env.DB.prepare(`SELECT * FROM games WHERE id = ?`).bind(game_id).first();
  }

  if (game.player_id !== player_id) {
    return json({ error: 'game_owner_mismatch' }, 403);
  }

  if (game.status === 'VALID' || game.status === 'FINISHED') {
    const existing = await env.DB.prepare(`SELECT score FROM scores WHERE game_id = ?`).bind(game_id).first();
    return json({ game_id, status: game.status, score: existing ? existing.score : score, idempotent: true });
  }

  const now = Date.now();
  const validationStatus = 'VALID';

  await env.DB.prepare(`
    INSERT INTO scores (game_id, player_id, score, validation_status, submitted_at)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(game_id) DO NOTHING
  `).bind(game_id, player_id, score, validationStatus, now).run();

  if (Array.isArray(events)) {
    await env.DB.prepare(`
      INSERT INTO game_events (game_id, events_json, submitted_at)
      VALUES (?, ?, ?)
      ON CONFLICT(game_id) DO NOTHING
    `).bind(game_id, JSON.stringify(events), now).run();
  }

  // Store cleared words into the player's vault.
  if (Array.isArray(body.words)) {
    for (const rawWord of body.words) {
      const word = String(rawWord || '').toUpperCase().trim();
      if (!/^[A-Z]{1,16}$/.test(word)) continue;
      await env.DB.prepare(`
        INSERT INTO collected_words (player_id, word, first_collected_at, times_collected)
        VALUES (?, ?, ?, 1)
        ON CONFLICT(player_id, word) DO UPDATE SET times_collected = times_collected + 1
      `).bind(player_id, word, now).run();
    }
  }

  await env.DB.prepare(`UPDATE games SET status = ?, finished_at = ? WHERE id = ?`)
    .bind(validationStatus, now, game_id).run();

  return json({ game_id, status: validationStatus, score });
}

// ----------------------------------------------------------------------------
// GET /v1/leaderboard/global?limit=100
// ----------------------------------------------------------------------------
async function handleLeaderboardGlobal(env, url) {
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '100', 10) || 100, 100);

  // GROUP BY p.id ensures each player only appears once, with their highest score.
  const results = await env.DB.prepare(`
    SELECT p.id AS player_id, p.display_name, p.country, MAX(s.score) AS score
    FROM scores s
    JOIN players p ON p.id = s.player_id
    WHERE s.validation_status = 'VALID'
    GROUP BY p.id
    ORDER BY score DESC
    LIMIT ?
  `).bind(limit).all();

  const leaderboard = results.results.map((row, i) => ({
    rank: i + 1,
    name: row.display_name,
    score: row.score,
    country: row.country || '',
  }));

  return json({ leaderboard });
}

// ----------------------------------------------------------------------------
// GET /v1/leaderboard/me?player_id=...
// ----------------------------------------------------------------------------
async function handleLeaderboardMe(env, url) {
  const playerId = url.searchParams.get('player_id');
  if (!playerId) {
    return json({ error: 'missing_player_id' }, 400);
  }

  const best = await env.DB.prepare(`
    SELECT MAX(score) AS best_score FROM scores
    WHERE player_id = ? AND validation_status = 'VALID'
  `).bind(playerId).first();

  const bestScore = best?.best_score ?? 0;
  let rank = null;
  if (bestScore > 0) {
    // Count how many *unique players* have a max score strictly greater than this player's best.
    const higher = await env.DB.prepare(`
      SELECT COUNT(*) AS cnt FROM (
        SELECT player_id FROM scores
        WHERE validation_status = 'VALID'
        GROUP BY player_id
        HAVING MAX(score) > ?
      )
    `).bind(bestScore).first();
    rank = (higher?.cnt ?? 0) + 1;
  }

  return json({ player_id: playerId, best_score: bestScore, rank });
}

// ----------------------------------------------------------------------------
// GET /v1/vault?player_id=...
// ----------------------------------------------------------------------------
async function handleVault(env, url) {
  const playerId = url.searchParams.get('player_id');
  if (!playerId) {
    return json({ error: 'missing_player_id' }, 400);
  }
  const results = await env.DB.prepare(`
    SELECT word, times_collected, first_collected_at
    FROM collected_words WHERE player_id = ?
    ORDER BY first_collected_at DESC
  `).bind(playerId).all();
  return json({ words: results.results });
}

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------
function randomSeed() {
  const arr = new Uint32Array(1);
  crypto.getRandomValues(arr);
  return arr[0]; 
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: corsHeaders({ 'Content-Type': 'application/json' }),
  });
}

function optionsResponse() {
  return new Response(null, { status: 204, headers: corsHeaders({}) });
}

function corsHeaders(extra) {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    ...extra,
  };
}

async function readJson(request) {
  try {
    return await request.json();
  } catch {
    return {};
  }
}