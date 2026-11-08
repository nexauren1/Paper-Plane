PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  uid TEXT PRIMARY KEY,
  pilot_code TEXT NOT NULL UNIQUE,
  pilot_name TEXT NOT NULL DEFAULT 'Piloto',
  language TEXT NOT NULL DEFAULT 'pt' CHECK (language IN ('pt','en')),
  country_code TEXT,
  country_visible INTEGER NOT NULL DEFAULT 0 CHECK (country_visible IN (0,1)),
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','CLOSED')),
  age_band TEXT NOT NULL DEFAULT 'UNVERIFIED' CHECK (age_band IN ('UNVERIFIED','UNDER_18','ADULT')),
  age_verified INTEGER NOT NULL DEFAULT 0 CHECK (age_verified IN (0,1)),
  age_verified_at TEXT,
  accept_random_mail INTEGER NOT NULL DEFAULT 1 CHECK (accept_random_mail IN (0,1)),
  push_enabled INTEGER NOT NULL DEFAULT 1 CHECK (push_enabled IN (0,1)),
  last_received_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (
    (age_band = 'UNVERIFIED' AND age_verified = 0) OR
    (age_band IN ('UNDER_18','ADULT') AND age_verified = 1)
  )
);

CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL DEFAULT 'android' CHECK (platform IN ('android','ios','web')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS daily_limits (
  uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  limit_date TEXT NOT NULL,
  original_planes INTEGER NOT NULL DEFAULT 0 CHECK (original_planes >= 0 AND original_planes <= 1),
  PRIMARY KEY (uid, limit_date)
);

CREATE TABLE IF NOT EXISTS airplanes (
  id TEXT PRIMARY KEY,
  sender_uid TEXT NOT NULL REFERENCES users(uid),
  recipient_uid TEXT REFERENCES users(uid),
  reply_to_id TEXT REFERENCES airplanes(id),
  audience TEXT NOT NULL CHECK (audience IN ('RANDOM','PUBLIC','DIRECT')),
  message_text TEXT NOT NULL CHECK (length(message_text) BETWEEN 1 AND 200),
  message_language TEXT NOT NULL DEFAULT 'pt' CHECK (message_language IN ('pt','en')),
  mood TEXT,
  destination_country TEXT,
  sender_country_code TEXT,
  allow_reply INTEGER NOT NULL DEFAULT 1 CHECK (allow_reply IN (0,1)),
  status TEXT NOT NULL CHECK (status IN ('QUEUED','FLYING','DELIVERED','READ','RESPONDED','RELEASED','EXPIRED','HELD_REVIEW','REJECTED')),
  moderation_state TEXT NOT NULL DEFAULT 'PENDING' CHECK (moderation_state IN ('PENDING','SAFE','REVIEW','UNSAFE')),
  moderation_categories TEXT,
  detected_language TEXT,
  detected_mood TEXT,
  theme_tag TEXT,
  content_hash TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  matched_at TEXT,
  delivered_at TEXT,
  read_at TEXT,
  expires_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_airplanes_sender_created ON airplanes(sender_uid, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_airplanes_queued ON airplanes(status, created_at);
CREATE INDEX IF NOT EXISTS idx_airplanes_recipient_status ON airplanes(recipient_uid, status, delivered_at DESC);
CREATE INDEX IF NOT EXISTS idx_airplanes_content_hash ON airplanes(sender_uid, content_hash, created_at DESC);

CREATE TABLE IF NOT EXISTS inbox (
  airplane_id TEXT PRIMARY KEY REFERENCES airplanes(id) ON DELETE CASCADE,
  recipient_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  opened_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_inbox_recipient_created ON inbox(recipient_uid, created_at DESC);

CREATE TABLE IF NOT EXISTS public_sky (
  airplane_id TEXT PRIMARY KEY REFERENCES airplanes(id) ON DELETE CASCADE,
  likes_count INTEGER NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS public_likes (
  airplane_id TEXT NOT NULL REFERENCES airplanes(id) ON DELETE CASCADE,
  uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (airplane_id, uid)
);

CREATE TABLE IF NOT EXISTS public_replies (
  id TEXT PRIMARY KEY,
  airplane_id TEXT NOT NULL REFERENCES airplanes(id) ON DELETE CASCADE,
  sender_uid TEXT NOT NULL REFERENCES users(uid),
  message_text TEXT NOT NULL CHECK (length(message_text) BETWEEN 1 AND 200),
  moderation_state TEXT NOT NULL DEFAULT 'PENDING' CHECK (moderation_state IN ('PENDING','SAFE','REVIEW','UNSAFE')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_public_replies_plane ON public_replies(airplane_id, created_at);

CREATE TABLE IF NOT EXISTS blocks (
  blocker_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  blocked_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (blocker_uid, blocked_uid),
  CHECK (blocker_uid <> blocked_uid)
);

CREATE TABLE IF NOT EXISTS reports (
  id TEXT PRIMARY KEY,
  reporter_uid TEXT NOT NULL REFERENCES users(uid),
  airplane_id TEXT REFERENCES airplanes(id),
  reported_uid TEXT REFERENCES users(uid),
  reason TEXT NOT NULL,
  details TEXT,
  status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','IN_REVIEW','ACTIONED','DISMISSED')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_reports_status_created ON reports(status, created_at);

CREATE TABLE IF NOT EXISTS translations (
  airplane_id TEXT NOT NULL REFERENCES airplanes(id) ON DELETE CASCADE,
  target_language TEXT NOT NULL CHECK (target_language IN ('pt','en')),
  translated_text TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (airplane_id, target_language)
);

CREATE TABLE IF NOT EXISTS audit_events (
  id TEXT PRIMARY KEY,
  actor_uid TEXT,
  event_type TEXT NOT NULL,
  entity_id TEXT,
  metadata_json TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_audit_events_created ON audit_events(created_at);
