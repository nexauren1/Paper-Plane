-- Pilot profile identity and long-running symbolic flights.
ALTER TABLE users ADD COLUMN pilot_handle TEXT;
ALTER TABLE users ADD COLUMN birth_year INTEGER;
ALTER TABLE users ADD COLUMN profile_completed INTEGER NOT NULL DEFAULT 0
  CHECK (profile_completed IN (0, 1));

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_pilot_handle_unique
  ON users(lower(pilot_handle))
  WHERE pilot_handle IS NOT NULL;

ALTER TABLE airplanes ADD COLUMN flight_distance_km INTEGER;
ALTER TABLE airplanes ADD COLUMN flight_duration_seconds INTEGER;
ALTER TABLE airplanes ADD COLUMN flight_started_at TEXT;
ALTER TABLE airplanes ADD COLUMN estimated_arrival_at TEXT;
ALTER TABLE airplanes ADD COLUMN route_json TEXT;

CREATE INDEX IF NOT EXISTS idx_airplanes_flight_arrival
  ON airplanes(status, estimated_arrival_at)
  WHERE status = 'FLYING';
