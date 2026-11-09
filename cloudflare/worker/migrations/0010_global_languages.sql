-- Multilingual preferences and cached translations without changing legacy locale fields.
ALTER TABLE users ADD COLUMN preferred_language TEXT NOT NULL DEFAULT 'pt';
ALTER TABLE airplanes ADD COLUMN message_language_tag TEXT NOT NULL DEFAULT 'pt';
ALTER TABLE chat_messages ADD COLUMN message_language_tag TEXT NOT NULL DEFAULT 'pt';

-- Preserve known legacy Portuguese/English values when adding the wider language tags.
UPDATE users SET preferred_language = language WHERE language IN ('pt', 'en');
UPDATE airplanes SET message_language_tag = message_language WHERE message_language IN ('pt', 'en');

CREATE TABLE IF NOT EXISTS airplane_translations (
  airplane_id TEXT NOT NULL REFERENCES airplanes(id) ON DELETE CASCADE,
  target_language TEXT NOT NULL,
  translated_text TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (airplane_id, target_language)
);

CREATE TABLE IF NOT EXISTS chat_translations (
  message_id TEXT NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
  target_language TEXT NOT NULL,
  translated_text TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (message_id, target_language)
);

INSERT OR IGNORE INTO airplane_translations(airplane_id, target_language, translated_text, created_at)
SELECT airplane_id, target_language, translated_text, created_at FROM translations;

CREATE INDEX IF NOT EXISTS idx_chat_translations_message
  ON chat_translations(message_id, target_language);
