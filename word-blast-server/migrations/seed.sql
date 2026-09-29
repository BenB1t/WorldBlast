INSERT OR IGNORE INTO rulesets (version, configuration_json, created_at)
VALUES (
  'ranked_v1',
  '{"version":"ranked_v1","board_size":8,"minimum_word_length":3,"horizontal":true,"vertical":true,"reverse_horizontal":false,"reverse_vertical":false,"diagonal":false,"gravity":false,"automatic_clear":false,"manual_clear":true,"word_reuse":false}',
  CAST(strftime('%s','now') AS INTEGER) * 1000
);