-- Public conversations are not capped at five replies per airplane.
-- The rolling per-account hourly safeguard in 0002_abuse_controls.sql remains active.
DROP TRIGGER IF EXISTS trg_public_replies_max_five;
