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


print("D1 migration checks passed: hourly limits, unique pilot handles, flight metadata, hearts and first-flight workshop.")
