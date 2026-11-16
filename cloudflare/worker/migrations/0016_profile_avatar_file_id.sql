-- Store ImageKit file IDs so replaced/deleted profile photos can be removed.
ALTER TABLE users ADD COLUMN avatar_file_id TEXT;
