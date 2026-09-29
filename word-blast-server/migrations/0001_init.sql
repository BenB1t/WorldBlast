-- Players (anonymous identity to start; account linking later)
CREATE TABLE IF NOT EXISTS players (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL DEFAULT 'Player',
  created_at INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL
);

-- Ranked games. The server owns the seed + ruleset + dictionary version.
CREATE TABLE IF NOT EXISTS games (
  id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL,
  seed INTEGER NOT NULL,
  ruleset_version TEXT NOT NULL,
  dictionary_version TEXT NOT NULL,
  generator_version TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  finished_at INTEGER,
  status TEXT NOT NULL DEFAULT 'STARTED',
  FOREIGN KEY (player_id) REFERENCES players(id)
);

-- Final scores. UNIQUE game_id makes resubmission idempotent.
CREATE TABLE IF NOT EXISTS scores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  game_id TEXT NOT NULL UNIQUE,
  player_id TEXT NOT NULL,
  score INTEGER NOT NULL,
  validation_status TEXT NOT NULL,
  submitted_at INTEGER NOT NULL,
  FOREIGN KEY (game_id) REFERENCES games(id),
  FOREIGN KEY (player_id) REFERENCES players(id)
);

-- Frozen rulesets. Historical games keep pointing at their original ruleset.
CREATE TABLE IF NOT EXISTS rulesets (
  version TEXT PRIMARY KEY,
  configuration_json TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

-- Submitted event logs, kept for Phase 6 server-side replay validation.
CREATE TABLE IF NOT EXISTS game_events (
  game_id TEXT PRIMARY KEY,
  events_json TEXT NOT NULL,
  submitted_at INTEGER NOT NULL,
  FOREIGN KEY (game_id) REFERENCES games(id)
);

CREATE INDEX IF NOT EXISTS idx_scores_valid_score ON scores (validation_status, score DESC);
CREATE INDEX IF NOT EXISTS idx_scores_player ON scores (player_id);
CREATE INDEX IF NOT EXISTS idx_games_player ON games (player_id);