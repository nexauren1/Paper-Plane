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
    "UPDATE users SET pilot_handle = ?, birth_year = ?, country_code = ?, profile_completed = 1 WHERE uid = ?",
    ("chuva_ocidental-07", 2008, "MZ", "pilot-a"),
)
try:
    DB.execute("UPDATE users SET pilot_handle = ? WHERE uid = ?", ("CHUVA_OCIDENTAL-07", "pilot-b"))
    raise AssertionError("Case-insensitive pilot handle uniqueness was not enforced")
except sqlite3.IntegrityError:
    pass

# Route and journey metadata are server-persisted fields.
airplane_columns = {
    row[1] for row in DB.execute("PRAGMA table_info(airplanes)").fetchall()
}
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
for uid, country in [
    ("sender", "MZ"),
    ("recipient-jp", "JP"),
    ("recipient-br", "BR"),
]:
    DB.execute(
        "UPDATE users SET country_code = ?, profile_completed = 1, age_band = 'ADULT', age_verified = 1 WHERE uid = ?",
        (country, uid),
    )

recipient_query = """
    SELECT u.uid, u.country_code, u.language
    FROM users u
    WHERE u.status = 'ACTIVE' AND u.profile_completed = 1 AND u.country_code IS NOT NULL
      AND u.age_verified = 1 AND u.age_band = ?
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

DB.execute("UPDATE users SET accept_random_mail = 0 WHERE uid = 'recipient-jp'")
fallback = DB.execute(recipient_query, bindings).fetchall()
assert fallback and all(row[0] != "recipient-jp" for row in fallback), "Ineligible destination pilot must be skipped"
assert any(row[0] == "recipient-br" for row in fallback), "Plane must fall back to an eligible pilot worldwide"

age_session_table = DB.execute(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'age_verification_sessions'"
).fetchone()
assert age_session_table is not None, "Missing age_verification_sessions table"

age_session_columns = {
    row[1] for row in DB.execute("PRAGMA table_info(age_verification_sessions)").fetchall()
}
assert {"uid", "provider_session_id", "reference_id", "stage", "status", "doc_scan_only"}.issubset(
    age_session_columns
), "Age assurance session table is incomplete"
assert not ({"document_image", "selfie_image", "biometric_payload", "birth_date"} & age_session_columns), (
    "D1 must not store raw identity documents, selfies, biometric payloads, or full birth dates"
)

DB.execute(
    """INSERT INTO age_verification_sessions(
        id, uid, provider_session_id, reference_id, stage, status
    ) VALUES ('age-session-1', 'pilot-a', 'provider-session-1', 'reference-1', 'MINIMUM_AGE', 'PENDING')"""
)
assert DB.execute(
    "SELECT uid FROM age_verification_sessions WHERE id = 'age-session-1'"
).fetchone()[0] == "pilot-a", "Age verification session must be bound to its Firebase UID"

try:
    DB.execute(
        """INSERT INTO age_verification_sessions(
            id, uid, provider_session_id, reference_id, stage, status
        ) VALUES ('age-session-2', 'pilot-b', 'provider-session-1', 'reference-2', 'MINIMUM_AGE', 'PENDING')"""
    )
    raise AssertionError("Provider session IDs must be unique")
except sqlite3.IntegrityError:
    pass

print("D1 migration checks passed: hourly limits, unique pilot handles, flight metadata, hearts and first-flight workshop and global recipient fallback.")
