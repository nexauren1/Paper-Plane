-- Social features are deliberately separate from the stranger-flight matching graph.
-- A friendship request never opens a private chat by itself; Chama is created only
-- when the recipient of a delivered airplane sends a private airplane reply.
DROP TABLE IF EXISTS daily_limits;

CREATE TABLE IF NOT EXISTS friendships (
  id TEXT PRIMARY KEY,
  requester_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  addressee_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE (requester_uid, addressee_uid),
  CHECK (requester_uid <> addressee_uid)
);

CREATE INDEX IF NOT EXISTS idx_friendships_addressee_status
  ON friendships(addressee_uid, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_friendships_requester_status
  ON friendships(requester_uid, status, created_at DESC);

CREATE TABLE IF NOT EXISTS conversations (
  id TEXT PRIMARY KEY,
  user_a TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  user_b TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  last_message_at TEXT,
  UNIQUE (user_a, user_b),
  CHECK (user_a < user_b)
);

CREATE INDEX IF NOT EXISTS idx_conversations_user_a
  ON conversations(user_a, last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_user_b
  ON conversations(user_b, last_message_at DESC);

CREATE TABLE IF NOT EXISTS chat_messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  message_text TEXT NOT NULL CHECK (length(message_text) BETWEEN 1 AND 1000),
  moderation_state TEXT NOT NULL DEFAULT 'SAFE' CHECK (moderation_state = 'SAFE'),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_created
  ON chat_messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_created
  ON chat_messages(sender_uid, created_at DESC);
