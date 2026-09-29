var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// src/index.js
var RULESET_VERSION = "ranked_v1";
var DICTIONARY_VERSION = "english_v1";
var GENERATOR_VERSION = "1";
var src_default = {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return optionsResponse();
    }
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;
    try {
      if (path === "/" || path === "/health") {
        return json({ status: "ok", service: "word-blast-api" });
      }
      if (path === "/v1/ranked/start" && method === "POST") {
        return await handleRankedStart(request, env);
      }
      if (path === "/v1/ranked/finish" && method === "POST") {
        return await handleRankedFinish(request, env);
      }
      if (path === "/v1/leaderboard/global" && method === "GET") {
        return await handleLeaderboardGlobal(env, url);
      }
      if (path === "/v1/leaderboard/me" && method === "GET") {
        return await handleLeaderboardMe(env, url);
      }
      if (path === "/v1/vault" && method === "GET") {
        return await handleVault(env, url);
      }
      return json({ error: "not_found" }, 404);
    } catch (err) {
      return json({ error: "internal", message: String(err) }, 500);
    }
  }
};
async function handleRankedStart(request, env) {
  const body = await readJson(request);
  const playerId = body?.player_id;
  if (!playerId || typeof playerId !== "string") {
    return json({ error: "missing_player_id" }, 400);
  }
  const countryRaw = typeof body?.country === "string" ? body.country.toUpperCase().trim() : "";
  const country = /^[A-Z]{2}$/.test(countryRaw) ? countryRaw : "";
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
  `).bind(playerId, String(body.display_name || "Player"), country, now, now).run();
  await env.DB.prepare(`
    INSERT INTO games
      (id, player_id, seed, ruleset_version, dictionary_version, generator_version, started_at, status)
    VALUES (?, ?, ?, ?, ?, ?, ?, 'STARTED')
  `).bind(gameId, playerId, seed, RULESET_VERSION, DICTIONARY_VERSION, GENERATOR_VERSION, now).run();
  return json({
    game_id: gameId,
    seed,
    ruleset_version: RULESET_VERSION,
    dictionary_version: DICTIONARY_VERSION
  });
}
__name(handleRankedStart, "handleRankedStart");
async function handleRankedFinish(request, env) {
  const body = await readJson(request);
  const { game_id, player_id, score, events, seed, ruleset_version } = body;
  if (!game_id || !player_id) {
    return json({ error: "missing_fields" }, 400);
  }
  if (typeof score !== "number" || !Number.isInteger(score) || score < 0) {
    return json({ error: "invalid_score" }, 400);
  }
  let game = await env.DB.prepare(`SELECT * FROM games WHERE id = ?`).bind(game_id).first();
  if (!game) {
    if (typeof seed !== "number" || !ruleset_version) {
      return json({ error: "missing_offline_game_data" }, 400);
    }
    const nowStart = Date.now();
    await env.DB.prepare(`
      INSERT INTO games (id, player_id, seed, ruleset_version, dictionary_version, generator_version, started_at, status, started_offline)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'STARTED', 1)
    `).bind(game_id, player_id, seed, ruleset_version, DICTIONARY_VERSION, GENERATOR_VERSION, nowStart).run();
    game = await env.DB.prepare(`SELECT * FROM games WHERE id = ?`).bind(game_id).first();
  }
  if (game.player_id !== player_id) {
    return json({ error: "game_owner_mismatch" }, 403);
  }
  if (game.status === "VALID" || game.status === "FINISHED") {
    const existing = await env.DB.prepare(`SELECT score FROM scores WHERE game_id = ?`).bind(game_id).first();
    return json({ game_id, status: game.status, score: existing ? existing.score : score, idempotent: true });
  }
  const now = Date.now();
  const validationStatus = "VALID";
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
  if (Array.isArray(body.words)) {
    for (const rawWord of body.words) {
      const word = String(rawWord || "").toUpperCase().trim();
      if (!/^[A-Z]{1,16}$/.test(word)) continue;
      await env.DB.prepare(`
        INSERT INTO collected_words (player_id, word, first_collected_at, times_collected)
        VALUES (?, ?, ?, 1)
        ON CONFLICT(player_id, word) DO UPDATE SET times_collected = times_collected + 1
      `).bind(player_id, word, now).run();
    }
  }
  await env.DB.prepare(`UPDATE games SET status = ?, finished_at = ? WHERE id = ?`).bind(validationStatus, now, game_id).run();
  return json({ game_id, status: validationStatus, score });
}
__name(handleRankedFinish, "handleRankedFinish");
async function handleLeaderboardGlobal(env, url) {
  const limit = Math.min(parseInt(url.searchParams.get("limit") || "100", 10) || 100, 100);
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
    country: row.country || ""
  }));
  return json({ leaderboard });
}
__name(handleLeaderboardGlobal, "handleLeaderboardGlobal");
async function handleLeaderboardMe(env, url) {
  const playerId = url.searchParams.get("player_id");
  if (!playerId) {
    return json({ error: "missing_player_id" }, 400);
  }
  const best = await env.DB.prepare(`
    SELECT MAX(score) AS best_score FROM scores
    WHERE player_id = ? AND validation_status = 'VALID'
  `).bind(playerId).first();
  const bestScore = best?.best_score ?? 0;
  let rank = null;
  if (bestScore > 0) {
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
__name(handleLeaderboardMe, "handleLeaderboardMe");
async function handleVault(env, url) {
  const playerId = url.searchParams.get("player_id");
  if (!playerId) {
    return json({ error: "missing_player_id" }, 400);
  }
  const results = await env.DB.prepare(`
    SELECT word, times_collected, first_collected_at
    FROM collected_words WHERE player_id = ?
    ORDER BY first_collected_at DESC
  `).bind(playerId).all();
  return json({ words: results.results });
}
__name(handleVault, "handleVault");
function randomSeed() {
  const arr = new Uint32Array(1);
  crypto.getRandomValues(arr);
  return arr[0];
}
__name(randomSeed, "randomSeed");
function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: corsHeaders({ "Content-Type": "application/json" })
  });
}
__name(json, "json");
function optionsResponse() {
  return new Response(null, { status: 204, headers: corsHeaders({}) });
}
__name(optionsResponse, "optionsResponse");
function corsHeaders(extra) {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    ...extra
  };
}
__name(corsHeaders, "corsHeaders");
async function readJson(request) {
  try {
    return await request.json();
  } catch {
    return {};
  }
}
__name(readJson, "readJson");

// node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } catch (e) {
    const error = reduceError(e);
    const body = JSON.stringify(error);
    const headers = {
      "Content-Type": "application/json",
      "MF-Experimental-Error-Stack": "true"
    };
    const encoded = encodeURIComponent(body);
    if (encoded.length <= 8192) {
      headers["MF-Experimental-Error-Stack-Payload"] = encoded;
    }
    return new Response(body, { status: 500, headers });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-bgu44c/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = src_default;

// node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-bgu44c/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class ___Facade_ScheduledController__ {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  scheduledTime;
  cron;
  static {
    __name(this, "__Facade_ScheduledController__");
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof ___Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = /* @__PURE__ */ __name((request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    }, "#fetchDispatcher");
    #dispatcher = /* @__PURE__ */ __name((type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    }, "#dispatcher");
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=index.js.map
