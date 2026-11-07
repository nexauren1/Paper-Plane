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
for index in range(9):
    DB.execute(
        """INSERT INTO public_replies(
            id, airplane_id, sender_uid, message_text, moderation_state
        ) VALUES (?, 'public-parent', 'pilot-c', 'A reply', 'SAFE')""",
        (f"combined-reply-{index}",),
    )

try:
    insert_plane("combined-over-limit", "pilot-c")
    raise AssertionError("Combined hourly trigger did not count public replies")
except sqlite3.IntegrityError as error:
    assert "PAPER_PLANE_RATE_LIMIT" in str(error), str(error)

print("D1 migration checks passed: hourly rate limit and five-reply limit.")
