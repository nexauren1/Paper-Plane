-- External profile images, Chat read receipts and explicit Chama closure.
ALTER TABLE users ADD COLUMN avatar_url TEXT;
ALTER TABLE chat_messages ADD COLUMN read_at TEXT;
ALTER TABLE conversations ADD COLUMN ended_at TEXT;

CREATE INDEX IF NOT EXISTS idx_chat_messages_read_receipts
  ON chat_messages(conversation_id, sender_uid, read_at, created_at DESC);
