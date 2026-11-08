-- First-party support inbox for bug reports and account or delivery issues.
-- User messages are private, category-limited, and visible only to their owner and authorized admins.
CREATE TABLE IF NOT EXISTS support_tickets (
  id TEXT PRIMARY KEY,
  uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  category TEXT NOT NULL CHECK (category IN ('TECHNICAL','ACCOUNT','DELIVERY','SAFETY','SUGGESTION','OTHER')),
  subject TEXT NOT NULL CHECK (length(subject) BETWEEN 3 AND 100),
  details TEXT NOT NULL CHECK (length(details) BETWEEN 10 AND 1200),
  status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','IN_REVIEW','RESOLVED','CLOSED')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_status_created
  ON support_tickets(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_support_tickets_uid_created
  ON support_tickets(uid, created_at DESC);
