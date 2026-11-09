-- Per-user conversation and airplane history controls.
-- Hiding a chat never deletes the other pilot's copy or message history.
ALTER TABLE conversations ADD COLUMN hidden_at_a TEXT;
ALTER TABLE conversations ADD COLUMN hidden_at_b TEXT;
ALTER TABLE airplanes ADD COLUMN sender_hidden_at TEXT;
ALTER TABLE airplanes ADD COLUMN cancelled_at TEXT;

CREATE INDEX IF NOT EXISTS idx_airplanes_sender_visible
  ON airplanes(sender_uid, sender_hidden_at, created_at DESC);
