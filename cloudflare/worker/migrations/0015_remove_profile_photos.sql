-- Profile photos are not part of the Paper Plane identity system.
-- Existing profile URLs are cleared; the schema column remains nullable for compatibility.
UPDATE users SET avatar_url = NULL WHERE avatar_url IS NOT NULL;
