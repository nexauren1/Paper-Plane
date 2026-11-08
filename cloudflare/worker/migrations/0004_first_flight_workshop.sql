-- Online first-flight workshop and paper-aircraft design selection.
ALTER TABLE airplanes ADD COLUMN plane_model TEXT NOT NULL DEFAULT 'DART'
  CHECK (plane_model IN ('DART','GLIDER','SWALLOW'));

CREATE TABLE IF NOT EXISTS onboarding_first_flights (
  uid TEXT PRIMARY KEY REFERENCES users(uid) ON DELETE CASCADE,
  message_text TEXT NOT NULL CHECK (length(message_text) BETWEEN 1 AND 200),
  plane_model TEXT NOT NULL CHECK (plane_model IN ('DART','GLIDER','SWALLOW')),
  state TEXT NOT NULL DEFAULT 'WAITING_FOR_AGE_VERIFICATION'
    CHECK (state IN ('WAITING_FOR_AGE_VERIFICATION','READY_TO_LAUNCH','LAUNCHED')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_onboarding_first_flights_state
  ON onboarding_first_flights(state, updated_at);
