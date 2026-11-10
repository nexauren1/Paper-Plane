from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[1]
DB = sqlite3.connect(":memory:")
DB.execute("PRAGMA foreign_keys = ON")

for migration in sorted((ROOT / "migrations").glob("*.sql")):
    DB.executescript(migration.read_text(encoding="utf-8"))

def seed_user(uid: str):
    DB.execute(
        "INSERT INTO users(uid, pilot_code, pilot_name) VALUES (?, ?, ?)",
        (uid, f"CODE-{uid}", "Pilot"),
    )

seed_user("pilot-a")
seed_user("pilot-b")

# Daily sending is unlimited; anti-spam remains a rolling hourly safeguard.
assert DB.execute(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'daily_limits'"
).fetchone() is None, "The obsolete one-plane-per-day counter must be removed"

user_columns = {row[1] for row in DB.execute("PRAGMA table_info(users)").fetchall()}
assert {"declared_age_band", "age_declaration_at", "preferred_language"}.issubset(user_columns), "Missing self-declared age or language fields"
DB.execute("UPDATE users SET language = 'en' WHERE uid = 'pilot-a'")
DB.execute("UPDATE users SET preferred_language = language WHERE language IN ('pt', 'en')")
assert DB.execute("SELECT preferred_language FROM users WHERE uid = 'pilot-a'").fetchone()[0] == "en", "Legacy profile language was not preserved"
DB.execute("UPDATE users SET preferred_language = 'ja' WHERE uid = 'pilot-a'")
assert DB.execute("SELECT preferred_language FROM users WHERE uid = 'pilot-a'").fetchone()[0] == "ja", "Japanese preference was not persisted"
assert DB.execute("SELECT declared_age_band FROM users WHERE uid = 'pilot-a'").fetchone()[0] == "UNSET", "New accounts must start without a declared age group"
assert "birth_date" not in user_columns, "Full birth dates must not be retained in D1"
assert DB.execute(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'age_verification_sessions'"
).fetchone() is None, "Third-party age verification sessions must be removed"

def insert_plane(plane_id: str, sender_uid: str, audience: str = "RANDOM"):
    DB.execute(
        """INSERT INTO airplanes(
            id, sender_uid, audience, message_text, message_language,
            allow_reply, status, moderation_state, content_hash
        ) VALUES (?, ?, ?, 'Hello', 'en', 1, 'QUEUED', 'SAFE', ?)""",
        (plane_id, sender_uid, audience, f"hash-{plane_id}"),
    )

# Exactly ten entries in the rolling hour are allowed; the eleventh is rejected.
for index in range(10):
    insert_plane(f"hourly-{index}", "pilot-a")

try:
    insert_plane("hourly-over-limit", "pilot-a")
    raise AssertionError("Hourly rate trigger did not block the eleventh message")
except sqlite3.IntegrityError as error:
    assert "PAPER_PLANE_RATE_LIMIT" in str(error), str(error)

# Five public replies are allowed, while the sixth is rejected atomically.
insert_plane("public-parent", "pilot-b", audience="PUBLIC")
insert_plane("public-parent-2", "pilot-b", audience="PUBLIC")
insert_plane("public-parent-3", "pilot-b", audience="PUBLIC")
for index in range(5):
    DB.execute(
        """INSERT INTO public_replies(
            id, airplane_id, sender_uid, message_text, moderation_state
        ) VALUES (?, 'public-parent', 'pilot-b', 'Kind words', 'SAFE')""",
        (f"reply-{index}",),
    )

try:
    DB.execute(
        """INSERT INTO public_replies(
            id, airplane_id, sender_uid, message_text, moderation_state
        ) VALUES ('reply-over-limit', 'public-parent', 'pilot-b', 'One more', 'SAFE')"""
    )
    raise AssertionError("Public reply trigger did not block the sixth reply")
except sqlite3.IntegrityError as error:
    assert "PUBLIC_REPLY_LIMIT_REACHED" in str(error), str(error)

# A pilot's combined hourly plane + reply allowance is shared.
seed_user("pilot-c")
insert_plane("combined-plane-1", "pilot-c")
for index in range(5):
    DB.execute(
        """INSERT INTO public_replies(
            id, airplane_id, sender_uid, message_text, moderation_state
        ) VALUES (?, 'public-parent-2', 'pilot-c', 'A reply', 'SAFE')""",
        (f"combined-reply-{index}",),
    )
for index in range(4):
    DB.execute(
        """INSERT INTO public_replies(
            id, airplane_id, sender_uid, message_text, moderation_state
        ) VALUES (?, 'public-parent-3', 'pilot-c', 'A reply', 'SAFE')""",
        (f"combined-reply-{index + 5}",),
    )

try:
    insert_plane("combined-over-limit", "pilot-c")
    raise AssertionError("Combined hourly trigger did not count public replies")
except sqlite3.IntegrityError as error:
    assert "PAPER_PLANE_RATE_LIMIT" in str(error), str(error)


# Pilot handle uniqueness is case-insensitive, and profile data is persisted.
DB.execute(
    "UPDATE users SET pilot_handle = ?, birth_year = ?, declared_age_band = ?, age_declaration_at = ?, country_code = ?, profile_completed = 1 WHERE uid = ?",
    ("chuva_ocidental-07", 2008, "UNDER_18", "2026-11-08T00:00:00Z", "MZ", "pilot-a"),
)
assert DB.execute(
    "SELECT birth_year, declared_age_band FROM users WHERE uid = 'pilot-a'"
).fetchone() == (2008, "UNDER_18"), "Self-declared age cohort was not persisted"
try:
    DB.execute("UPDATE users SET pilot_handle = ? WHERE uid = ?", ("CHUVA_OCIDENTAL-07", "pilot-b"))
    raise AssertionError("Case-insensitive pilot handle uniqueness was not enforced")
except sqlite3.IntegrityError:
    pass

# Route and journey metadata are server-persisted fields.
airplane_columns = {
    row[1] for row in DB.execute("PRAGMA table_info(airplanes)").fetchall()
}
assert "message_language_tag" in airplane_columns, "Missing full source-language tag on airplanes"
required_flight_columns = {
    "flight_distance_km",
    "flight_duration_seconds",
    "flight_started_at",
    "estimated_arrival_at",
    "route_json",
}
assert required_flight_columns.issubset(airplane_columns), "Missing persisted flight columns"

heart_table = DB.execute(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'airplane_hearts'"
).fetchone()
assert heart_table is not None, "Missing airplane_hearts table"

first_flight_table = DB.execute(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'onboarding_first_flights'"
).fetchone()
assert first_flight_table is not None, "Missing onboarding_first_flights table"

plane_model_column = DB.execute(
    "SELECT name FROM pragma_table_info('airplanes') WHERE name = 'plane_model'"
).fetchone()
assert plane_model_column is not None, "Missing airplane plane_model column"



# Random flight matching prefers the requested country but must fall back globally.
seed_user("sender")
seed_user("recipient-jp")
seed_user("recipient-br")
seed_user("recipient-minor")
for uid, country, declared_band in [
    ("sender", "MZ", "ADULT"),
    ("recipient-jp", "JP", "ADULT"),
    ("recipient-br", "BR", "ADULT"),
    ("recipient-minor", "ZA", "UNDER_18"),
]:
    DB.execute(
        "UPDATE users SET country_code = ?, profile_completed = 1, declared_age_band = ? WHERE uid = ?",
        (country, declared_band, uid),
    )

recipient_query = """
    SELECT u.uid, u.country_code, u.language
    FROM users u
    WHERE u.status = 'ACTIVE' AND u.profile_completed = 1 AND u.country_code IS NOT NULL
      AND u.declared_age_band = ?
      AND u.accept_random_mail = 1 AND u.uid <> ?
      AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE (b.blocker_uid = ? AND b.blocked_uid = u.uid)
           OR (b.blocker_uid = u.uid AND b.blocked_uid = ?)
      )
      AND NOT EXISTS (
        SELECT 1 FROM reports r
        WHERE r.reporter_uid = u.uid AND r.reported_uid = ? AND r.status = 'OPEN'
      )
    ORDER BY CASE WHEN ? IS NOT NULL AND u.country_code = ? THEN 0 ELSE 1 END,
      COALESCE(u.last_received_at, '1970-01-01T00:00:00.000Z') ASC,
      u.uid ASC
    LIMIT 40
"""
bindings = ("ADULT", "sender", "sender", "sender", "sender", "JP", "JP")
preferred = DB.execute(recipient_query, bindings).fetchall()
assert preferred and preferred[0][0] == "recipient-jp", "Requested country should be preferred"
assert all(row[0] != "recipient-minor" for row in preferred), "Random matching must never cross declared age groups"

DB.execute("UPDATE users SET accept_random_mail = 0 WHERE uid = 'recipient-jp'")
fallback = DB.execute(recipient_query, bindings).fetchall()
assert fallback and all(row[0] != "recipient-jp" for row in fallback), "Ineligible destination pilot must be skipped"
assert any(row[0] == "recipient-br" for row in fallback), "Plane must fall back to an eligible pilot worldwide"

# Categorized support tickets must be private to an account and use controlled statuses.
support_table = DB.execute(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'support_tickets'"
).fetchone()
assert support_table is not None, "Missing support_tickets table"

support_columns = {
    row[1] for row in DB.execute("PRAGMA table_info(support_tickets)").fetchall()
}
assert {"uid", "category", "subject", "details", "status", "created_at", "updated_at"}.issubset(
    support_columns
), "Support ticket schema is incomplete"
assert not ({"email", "phone", "birth_date", "document_image"} & support_columns), (
    "Support tickets must not duplicate sensitive account or identity data"
)

DB.execute(
    """INSERT INTO support_tickets(id, uid, category, subject, details)
       VALUES ('support-1', 'pilot-a', 'TECHNICAL', 'App freezes', 'The inbox freezes after opening a new plane.')"""
)
support_ticket = DB.execute(
    "SELECT uid, category, status FROM support_tickets WHERE id = 'support-1'"
).fetchone()
assert support_ticket == ("pilot-a", "TECHNICAL", "OPEN"), "Support ticket defaults are incorrect"

try:
    DB.execute(
        """INSERT INTO support_tickets(id, uid, category, subject, details)
           VALUES ('support-invalid', 'pilot-a', 'UNKNOWN', 'Invalid', 'Invalid category test')"""
    )
    raise AssertionError("Support ticket accepted an invalid category")
except sqlite3.IntegrityError:
    pass


# Social graph and Chama chat are separate: adding a friend does not create a conversation.
social_tables = {
    row[0] for row in DB.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table'"
    ).fetchall()
}
assert {"friendships", "conversations", "chat_messages", "airplane_translations", "chat_translations"}.issubset(social_tables), "Missing social, Chama or translation tables"
chat_message_columns = {
    row[1] for row in DB.execute("PRAGMA table_info(chat_messages)").fetchall()
}
assert "message_language_tag" in chat_message_columns, "Missing full source-language tag on chat messages"

DB.execute(
    "UPDATE users SET declared_age_band = 'UNDER_18', profile_completed = 1 WHERE uid IN ('pilot-a','pilot-b')"
)
DB.execute(
    """INSERT INTO friendships(id, requester_uid, addressee_uid, status)
       VALUES ('friend-1', 'pilot-a', 'pilot-b', 'ACCEPTED')"""
)
assert DB.execute(
    "SELECT status FROM friendships WHERE id = 'friend-1'"
).fetchone()[0] == "ACCEPTED", "Friendship request state was not persisted"

DB.execute(
    """INSERT INTO conversations(id, user_a, user_b)
       VALUES ('chama-1', 'pilot-a', 'pilot-b')"""
)
DB.execute(
    """INSERT INTO chat_messages(id, conversation_id, sender_uid, message_text, message_language_tag)
       VALUES ('chat-1', 'chama-1', 'pilot-a', 'Olá, tudo bem?', 'pt')"""
)
assert DB.execute(
    "SELECT message_text, message_language_tag FROM chat_messages WHERE id = 'chat-1'"
).fetchone() == ("Olá, tudo bem?", "pt"), "Chama message or its language tag was not persisted"
DB.execute(
    """INSERT INTO chat_translations(message_id, target_language, translated_text)
       VALUES ('chat-1', 'ja', 'こんにちは、お元気ですか？')"""
)
assert DB.execute(
    "SELECT translated_text FROM chat_translations WHERE message_id = 'chat-1' AND target_language = 'ja'"
).fetchone()[0] == "こんにちは、お元気ですか？", "Japanese chat translation cache failed"
insert_plane("lang-plane", "pilot-b")
DB.execute(
    """INSERT INTO airplane_translations(airplane_id, target_language, translated_text)
       VALUES ('lang-plane', 'ja', 'こんにちは')"""
)
assert DB.execute(
    "SELECT translated_text FROM airplane_translations WHERE airplane_id = 'lang-plane' AND target_language = 'ja'"
).fetchone()[0] == "こんにちは", "Japanese airplane translation cache failed"

try:
    DB.execute(
        """INSERT INTO conversations(id, user_a, user_b)
           VALUES ('chama-invalid', 'pilot-b', 'pilot-a')"""
    )
    raise AssertionError("Conversation user order must be canonical")
except sqlite3.IntegrityError:
    pass

print("D1 migration checks passed: unlimited daily sends with hourly abuse controls, expiry metadata, friendships, delivered-reply Chama tables, route data, matching, reporting and support.")


# Chama and direct Chat remain separate for the same pair of pilots.
conversation_columns = {
    row[1] for row in DB.execute("PRAGMA table_info(conversations)").fetchall()
}
assert "kind" in conversation_columns, "Conversations need a CHAT/CHAMA kind"
DB.execute(
    "INSERT INTO conversations(id, user_a, user_b, kind) VALUES ('chat-1', 'pilot-a', 'pilot-b', 'CHAT')"
)
assert DB.execute(
    "SELECT COUNT(*) FROM conversations WHERE user_a = 'pilot-a' AND user_b = 'pilot-b'"
).fetchone()[0] == 2, "A pair must be able to have independent Chat and Chama conversations"

# Persistent quiz history and one-time XP mission claims.
assert DB.execute(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'quiz_attempts'"
).fetchone() is not None, "Missing quiz attempt history"
assert DB.execute(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'pilot_reward_claims'"
).fetchone() is not None, "Missing mission reward ledger"
DB.execute(
    """INSERT INTO quiz_attempts(id, uid, category, question_count, correct_count, xp_awarded)
       VALUES ('quiz-1', 'pilot-a', 'Geografia', 10, 8, 26)"""
)
DB.execute(
    """INSERT INTO pilot_reward_claims(uid, mission_key, xp)
       VALUES ('pilot-a', 'send_five', 60)"""
)
try:
    DB.execute(
        """INSERT INTO pilot_reward_claims(uid, mission_key, xp)
           VALUES ('pilot-a', 'send_five', 60)"""
    )
    raise AssertionError("Mission reward was claimed twice")
except sqlite3.IntegrityError:
    pass


# External profile photos, private Chat read receipts and Chama closure.
user_columns = {row[1] for row in DB.execute("PRAGMA table_info(users)").fetchall()}
chat_message_columns = {row[1] for row in DB.execute("PRAGMA table_info(chat_messages)").fetchall()}
conversation_columns = {row[1] for row in DB.execute("PRAGMA table_info(conversations)").fetchall()}
assert "avatar_url" in user_columns, "Missing public profile avatar URL"
assert "read_at" in chat_message_columns, "Missing private Chat read receipt"
assert "ended_at" in conversation_columns, "Missing Chama route closure field"
DB.execute("UPDATE users SET avatar_url = ? WHERE uid = ?", ("https://images.example.test/pilot.jpg", "pilot-a"))
assert DB.execute("SELECT avatar_url FROM users WHERE uid = 'pilot-a'").fetchone()[0] == "https://images.example.test/pilot.jpg"
DB.execute(
    "UPDATE chat_messages SET read_at = '2026-11-09T12:00:00.000Z' WHERE id = 'chat-1'"
)
assert DB.execute("SELECT read_at FROM chat_messages WHERE id = 'chat-1'").fetchone()[0] == "2026-11-09T12:00:00.000Z"
DB.execute(
    "UPDATE conversations SET ended_at = '2026-11-09T12:05:00.000Z' WHERE id = 'chama-1'"
)
assert DB.execute("SELECT ended_at FROM conversations WHERE id = 'chama-1'").fetchone()[0] == "2026-11-09T12:05:00.000Z"


# Release-hardening tables: Admin notification history and privacy deletion tombstones.
assert DB.execute(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'admin_notifications'"
).fetchone() is not None, "Missing admin_notifications history table"
assert DB.execute(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'deleted_accounts'"
).fetchone() is not None, "Missing deleted_accounts tombstone table"

DB.execute(
    """INSERT INTO admin_notifications(
         id, actor_uid, target_type, recipient_uid, title, body,
         device_count, sent_count, failed_count
       ) VALUES ('admin-notice-1', 'pilot-a', 'ALL', NULL, 'Update', 'A test notice', 12, 12, 0)"""
)
assert DB.execute(
    "SELECT target_type, device_count, sent_count FROM admin_notifications WHERE id = 'admin-notice-1'"
).fetchone() == ("ALL", 12, 12), "Admin announcement history did not persist"

DB.execute("INSERT INTO deleted_accounts(uid_hash) VALUES ('sha256-test-tombstone')")
assert DB.execute(
    "SELECT COUNT(*) FROM deleted_accounts WHERE uid_hash = 'sha256-test-tombstone'"
).fetchone()[0] == 1, "Account deletion tombstone did not persist"
try:
    DB.execute("INSERT INTO deleted_accounts(uid_hash) VALUES ('sha256-test-tombstone')")
    raise AssertionError("Deleted account UID tombstone must be unique")
except sqlite3.IntegrityError:
    pass

print("Release hardening checks passed: Admin notification history and unique account-deletion tombstones.")
