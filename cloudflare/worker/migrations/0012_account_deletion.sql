-- Store only a one-way account identifier hash to prevent an erased Firebase UID
-- from silently creating a fresh Paper Plane profile on the next bootstrap.
CREATE TABLE IF NOT EXISTS deleted_accounts (
  uid_hash TEXT PRIMARY KEY,
  deleted_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_deleted_accounts_deleted_at
  ON deleted_accounts(deleted_at DESC);
