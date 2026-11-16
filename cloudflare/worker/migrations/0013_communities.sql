-- Age-band scoped communities with server-moderated group conversations.
CREATE TABLE IF NOT EXISTS social_groups (
  id TEXT PRIMARY KEY,
  owner_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(name) BETWEEN 3 AND 40),
  description TEXT NOT NULL DEFAULT '' CHECK (length(description) <= 160),
  category TEXT NOT NULL DEFAULT 'GENERAL'
    CHECK (category IN ('TECH', 'TRAVEL', 'LANGUAGE', 'CULTURE', 'GAMING', 'GENERAL')),
  age_band TEXT NOT NULL CHECK (age_band IN ('UNDER_18', 'ADULT')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_social_groups_band_category_created
  ON social_groups(age_band, category, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_social_groups_owner_created
  ON social_groups(owner_uid, created_at DESC);

CREATE TABLE IF NOT EXISTS social_group_members (
  group_id TEXT NOT NULL REFERENCES social_groups(id) ON DELETE CASCADE,
  uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'MEMBER' CHECK (role IN ('OWNER', 'MEMBER')),
  joined_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (group_id, uid)
);

CREATE INDEX IF NOT EXISTS idx_social_group_members_uid_joined
  ON social_group_members(uid, joined_at DESC);
CREATE INDEX IF NOT EXISTS idx_social_group_members_group_joined
  ON social_group_members(group_id, joined_at ASC);

CREATE TABLE IF NOT EXISTS social_group_messages (
  id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL REFERENCES social_groups(id) ON DELETE CASCADE,
  uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  message_text TEXT NOT NULL CHECK (length(message_text) BETWEEN 1 AND 500),
  moderation_state TEXT NOT NULL DEFAULT 'SAFE' CHECK (moderation_state = 'SAFE'),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_social_group_messages_group_created
  ON social_group_messages(group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_social_group_messages_uid_created
  ON social_group_messages(uid, created_at DESC);

-- Enforce age cohort and membership even if a future handler forgets a check.
CREATE TRIGGER IF NOT EXISTS social_group_member_age_band_guard
BEFORE INSERT ON social_group_members
BEGIN
  SELECT CASE
    WHEN (SELECT age_band FROM social_groups WHERE id = NEW.group_id)
       <> (SELECT declared_age_band FROM users WHERE uid = NEW.uid)
    THEN RAISE(ABORT, 'GROUP_AGE_BAND_MISMATCH')
  END;
END;

CREATE TRIGGER IF NOT EXISTS social_group_message_membership_guard
BEFORE INSERT ON social_group_messages
BEGIN
  SELECT CASE
    WHEN NOT EXISTS (
      SELECT 1 FROM social_group_members m
      JOIN social_groups g ON g.id = m.group_id
      JOIN users u ON u.uid = m.uid
      WHERE m.group_id = NEW.group_id AND m.uid = NEW.uid
        AND g.age_band = u.declared_age_band
    )
    THEN RAISE(ABORT, 'GROUP_MEMBERSHIP_REQUIRED')
  END;
END;
