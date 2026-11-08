-- Age assurance provider sessions. Only the provider session reference and resulting age band are stored.
-- Raw identity documents, selfies, full dates of birth, and biometric payloads are never stored in D1.
CREATE TABLE IF NOT EXISTS age_verification_sessions (
  id TEXT PRIMARY KEY,
  uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  provider TEXT NOT NULL DEFAULT 'YOTI' CHECK (provider IN ('YOTI')),
  provider_session_id TEXT NOT NULL UNIQUE,
  reference_id TEXT NOT NULL UNIQUE,
  stage TEXT NOT NULL CHECK (stage IN ('MINIMUM_AGE', 'AGE_BAND')),
  status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'VERIFIED', 'FAILED', 'ERROR', 'SUPERSEDED')),
  method TEXT,
  doc_scan_only INTEGER NOT NULL DEFAULT 0 CHECK (doc_scan_only IN (0, 1)),
  expires_at TEXT,
  completed_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_age_verification_uid_status
  ON age_verification_sessions(uid, status, created_at DESC);
