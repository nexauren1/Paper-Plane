-- Auditable history for targeted and global operator announcements.
CREATE TABLE IF NOT EXISTS admin_notifications (
  id TEXT PRIMARY KEY,
  actor_uid TEXT NOT NULL,
  target_type TEXT NOT NULL CHECK (target_type IN ('ALL', 'USER')),
  recipient_uid TEXT,
  title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 80),
  body TEXT NOT NULL CHECK (length(body) BETWEEN 1 AND 220),
  device_count INTEGER NOT NULL DEFAULT 0 CHECK (device_count >= 0),
  sent_count INTEGER NOT NULL DEFAULT 0 CHECK (sent_count >= 0),
  failed_count INTEGER NOT NULL DEFAULT 0 CHECK (failed_count >= 0),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_admin_notifications_created
  ON admin_notifications(created_at DESC);
