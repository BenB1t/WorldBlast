CREATE TABLE IF NOT EXISTS collected_words (
  player_id TEXT NOT NULL,
  word TEXT NOT NULL,
  first_collected_at INTEGER NOT NULL,
  times_collected INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (player_id, word),
  FOREIGN KEY (player_id) REFERENCES players(id)
);
CREATE INDEX IF NOT EXISTS idx_collected_player ON collected_words (player_id);