-- Separate direct friend chats from Chama conversations created by delivered reply planes.
-- Rebuild the pair table so the same two pilots can have independent CHAT and CHAMA threads.
PRAGMA foreign_keys = OFF;

CREATE TABLE conversations_new (
  id TEXT PRIMARY KEY,
  user_a TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  user_b TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  kind TEXT NOT NULL DEFAULT 'CHAMA' CHECK (kind IN ('CHAMA', 'CHAT')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  last_message_at TEXT,
  UNIQUE (user_a, user_b, kind),
  CHECK (user_a < user_b)
);

INSERT INTO conversations_new(id, user_a, user_b, kind, created_at, last_message_at)
SELECT id, user_a, user_b, 'CHAMA', created_at, last_message_at
FROM conversations;

DROP TABLE conversations;
ALTER TABLE conversations_new RENAME TO conversations;

CREATE INDEX IF NOT EXISTS idx_conversations_user_a
  ON conversations(user_a, kind, last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_user_b
  ON conversations(user_b, kind, last_message_at DESC);

CREATE TABLE IF NOT EXISTS quiz_attempts (
  id TEXT PRIMARY KEY,
  uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  category TEXT NOT NULL,
  question_count INTEGER NOT NULL CHECK (question_count = 10),
  correct_count INTEGER NOT NULL CHECK (correct_count >= 0 AND correct_count <= question_count),
  xp_awarded INTEGER NOT NULL CHECK (xp_awarded >= 10 AND xp_awarded <= 30),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_uid_created
  ON quiz_attempts(uid, created_at DESC);

CREATE TABLE IF NOT EXISTS pilot_reward_claims (
  uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  mission_key TEXT NOT NULL,
  xp INTEGER NOT NULL CHECK (xp > 0),
  claimed_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (uid, mission_key)
);
CREATE INDEX IF NOT EXISTS idx_pilot_reward_claims_uid
  ON pilot_reward_claims(uid, claimed_at DESC);

PRAGMA foreign_keys = ON;
