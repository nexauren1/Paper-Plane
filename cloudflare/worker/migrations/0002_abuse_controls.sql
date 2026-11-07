-- Abuse controls enforced inside D1 so concurrent requests cannot bypass them.
-- An account may create at most 10 planes/replies in any rolling hour.
-- A public plane may have at most 5 public replies.

CREATE TRIGGER IF NOT EXISTS trg_airplanes_hourly_rate_limit
BEFORE INSERT ON airplanes
WHEN
  (SELECT COUNT(*) FROM airplanes
   WHERE sender_uid = NEW.sender_uid
     AND created_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 hour'))
  +
  (SELECT COUNT(*) FROM public_replies
   WHERE sender_uid = NEW.sender_uid
     AND created_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 hour'))
  >= 10
BEGIN
  SELECT RAISE(ABORT, 'PAPER_PLANE_RATE_LIMIT');
END;

CREATE TRIGGER IF NOT EXISTS trg_public_replies_hourly_rate_limit
BEFORE INSERT ON public_replies
WHEN
  (SELECT COUNT(*) FROM airplanes
   WHERE sender_uid = NEW.sender_uid
     AND created_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 hour'))
  +
  (SELECT COUNT(*) FROM public_replies
   WHERE sender_uid = NEW.sender_uid
     AND created_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 hour'))
  >= 10
BEGIN
  SELECT RAISE(ABORT, 'PAPER_PLANE_RATE_LIMIT');
END;

CREATE TRIGGER IF NOT EXISTS trg_public_replies_max_five
BEFORE INSERT ON public_replies
WHEN
  (SELECT COUNT(*) FROM public_replies WHERE airplane_id = NEW.airplane_id) >= 5
BEGIN
  SELECT RAISE(ABORT, 'PUBLIC_REPLY_LIMIT_REACHED');
END;
