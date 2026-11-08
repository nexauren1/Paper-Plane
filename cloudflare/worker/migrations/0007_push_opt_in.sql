-- Push notifications must be explicit opt-in.
-- Keep the account flag enabled only when at least one device has a registered token.
UPDATE users
SET push_enabled = 0
WHERE NOT EXISTS (
  SELECT 1 FROM devices d WHERE d.uid = users.uid
);
