-- Replace third-party age verification with a transparent, self-declared age group.
-- The full date of birth is submitted to the Worker for calculation, but only the year
-- and the derived cohort are retained in D1.
ALTER TABLE users ADD COLUMN declared_age_band TEXT NOT NULL DEFAULT 'UNSET'
  CHECK (declared_age_band IN ('UNSET', 'UNDER_18', 'ADULT'));
ALTER TABLE users ADD COLUMN age_declaration_at TEXT;

-- Historical verification flags are no longer used as a gate or represented as current proof.
UPDATE users
SET age_band = 'UNVERIFIED',
    age_verified = 0,
    age_verified_at = NULL,
    declared_age_band = 'UNSET',
    age_declaration_at = NULL,
    profile_completed = 0;

-- Saved first-flight drafts no longer wait for an external verification provider.
UPDATE onboarding_first_flights
SET state = 'READY_TO_LAUNCH',
    updated_at = strftime('%Y-%m-%dT%H:%M:%fZ','now')
WHERE state = 'WAITING_FOR_AGE_VERIFICATION';

DROP TABLE IF EXISTS age_verification_sessions;

CREATE INDEX IF NOT EXISTS idx_users_declared_age_matching
  ON users(status, profile_completed, declared_age_band, accept_random_mail);
