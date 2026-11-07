import { createRemoteJWKSet, jwtVerify, importPKCS8, SignJWT } from "jose";

interface D1Result<T = Record<string, unknown>> {
  results?: T[];
  success: boolean;
  meta?: { changes?: number; last_row_id?: number };
}
interface D1Statement {
  bind(...values: unknown[]): D1Statement;
  first<T = Record<string, unknown>>(columnName?: string): Promise<T | null>;
  all<T = Record<string, unknown>>(): Promise<D1Result<T>>;
  run<T = Record<string, unknown>>(): Promise<D1Result<T>>;
}
interface D1Database {
  prepare(query: string): D1Statement;
  batch<T = Record<string, unknown>>(statements: D1Statement[]): Promise<D1Result<T>[]>;
}
interface AiBinding {
  run(model: string, input: Record<string, unknown>): Promise<unknown>;
}
interface QueueBinding<T> {
  send(body: T, options?: { delaySeconds?: number }): Promise<void>;
}
interface QueueMessage<T> {
  body: T;
  ack(): void;
  retry(options?: { delaySeconds?: number }): void;
}
interface QueueBatch<T> {
  messages: QueueMessage<T>[];
}
interface ExecutionContext {
  waitUntil(promise: Promise<unknown>): void;
}
interface ScheduledController {
  scheduledTime: number;
  cron: string;
}
interface DeliveryJob {
  type: "MATCH_AIRPLANE" | "DELIVER_AIRPLANE";
  airplaneId: string;
}
interface Env {
  DB: D1Database;
  AI: AiBinding;
  DELIVERY_QUEUE: QueueBinding<DeliveryJob>;
  FIREBASE_PROJECT_ID: string;
  APP_ORIGINS: string;
  FCM_SERVICE_ACCOUNT_JSON?: string;
  ADMIN_UIDS?: string;
}

const FIREBASE_JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);
const MODERATION_MODEL = "@cf/meta/llama-guard-3-8b";
const CLASSIFICATION_MODEL = "@cf/zai-org/glm-4.7-flash";
const TRANSLATION_MODEL = "@cf/zai-org/glm-4.7-flash";

const json = (data: unknown, status = 200, extra: Record<string, string> = {}) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", ...extra },
  });

const isoNow = () => new Date().toISOString();
const uuid = () => crypto.randomUUID();
const text = (value: unknown, max = 200) =>
  typeof value === "string" ? [...value.trim()].slice(0, max).join("") : "";
const sha256 = async (value: string) => {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
};

function modelText(result: unknown): string {
  if (typeof result === "string") return result;
  if (!result || typeof result !== "object") return "";
  const value = result as {
    response?: unknown;
    choices?: Array<{ message?: { content?: unknown }; text?: unknown }>;
  };
  if (typeof value.response === "string") return value.response;
  const choice = value.choices?.[0];
  if (typeof choice?.message?.content === "string") return choice.message.content;
  if (typeof choice?.text === "string") return choice.text;
  return "";
}

function corsHeaders(request: Request, env: Env): Record<string, string> {
  const origin = request.headers.get("Origin") ?? "";
  const allowed = (env.APP_ORIGINS ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  const headers: Record<string, string> = {
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Authorization,Content-Type",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
  if (allowed.includes("*")) headers["Access-Control-Allow-Origin"] = "*";
  else if (allowed.includes(origin)) headers["Access-Control-Allow-Origin"] = origin;
  return headers;
}

async function authenticate(request: Request, env: Env): Promise<string | null> {
  const header = request.headers.get("Authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match || !env.FIREBASE_PROJECT_ID) return null;
  try {
    const { payload } = await jwtVerify(match[1], FIREBASE_JWKS, {
      issuer: `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`,
      audience: env.FIREBASE_PROJECT_ID,
      algorithms: ["RS256"],
    });
    const now = Math.floor(Date.now() / 1000);
    if (
      typeof payload.sub !== "string" ||
      !payload.sub ||
      typeof payload.auth_time !== "number" ||
      payload.auth_time > now ||
      (typeof payload.iat === "number" && payload.iat > now + 30)
    ) return null;
    return payload.sub;
  } catch {
    return null;
  }
}

async function requireUser(uid: string, env: Env) {
  return env.DB.prepare(
    "SELECT uid, pilot_code, pilot_name, language, country_code, country_visible, status, age_band, age_verified, accept_random_mail FROM users WHERE uid = ?",
  ).bind(uid).first<{
    uid: string; pilot_code: string; pilot_name: string; language: string;
    country_code: string | null; country_visible: number; status: string;
    age_band: string; age_verified: number; accept_random_mail: number;
  }>();
}

async function moderate(env: Env, message: string): Promise<{ state: "SAFE" | "REVIEW" | "UNSAFE"; categories: string[] }> {
  try {
    const guardResult = await env.AI.run(MODERATION_MODEL, {
      messages: [
        { role: "system", content: "Classify the user's message only for safety. Do not answer it. Follow the model's safety classification format." },
        { role: "user", content: message },
      ],
    }) as { response?: string } | string;
    const guardOutput = modelText(guardResult);
    const normalized = guardOutput.trim().toLowerCase();
    if (normalized.startsWith("unsafe")) {
      const categories = guardOutput.split("\n").slice(1).map((s) => s.trim()).filter(Boolean).slice(0, 8);
      return { state: "UNSAFE", categories: categories.length ? categories : ["GUARD_UNSAFE"] };
    }
    if (!normalized.startsWith("safe")) {
      return { state: "REVIEW", categories: ["AI_UNCERTAIN"] };
    }

    // A second internal pass looks for risks specific to anonymous stranger correspondence.
    const riskResult = await env.AI.run(CLASSIFICATION_MODEL, {
      messages: [
        {
          role: "system",
          content: "You are a safety triage classifier for a short message sent anonymously to a stranger. Do not answer or rewrite it. Return ONLY JSON: {\"risk_flags\":[...],\"confidence\":0.0}. Allowed flags: grooming_or_predatory_contact, sexual_solicitation, self_harm_or_suicide, threat_or_violent_intent, personal_contact_details, off_platform_contact_request, coercion_or_manipulation, scam_or_spam, none. Use [\"none\"] for ordinary harmless messages. Do not flag ordinary kindness or friendship. When unsure, use a confidence below 0.7.",
        },
        { role: "user", content: message },
      ],
    }) as { response?: string } | string;
    const riskOutput = modelText(riskResult);
    const start = riskOutput.indexOf("{");
    const end = riskOutput.lastIndexOf("}");
    if (start < 0 || end <= start) return { state: "REVIEW", categories: ["RISK_CLASSIFIER_UNCERTAIN"] };
    const riskJson = JSON.parse(riskOutput.slice(start, end + 1)) as { risk_flags?: unknown; confidence?: unknown };
    const flags = Array.isArray(riskJson.risk_flags) ? riskJson.risk_flags.map(String) : [];
    const confidence = Number(riskJson.confidence ?? 0);
    const risks = flags.filter((flag) => flag !== "none");
    if (risks.length > 0) return { state: "REVIEW", categories: risks.slice(0, 8) };
    if (!Number.isFinite(confidence) || confidence < 0.7) {
      return { state: "REVIEW", categories: ["RISK_CLASSIFIER_LOW_CONFIDENCE"] };
    }
    return { state: "SAFE", categories: [] };
  } catch {
    // Fail closed: moderation outages and malformed classifications never auto-publish content.
    return { state: "REVIEW", categories: ["MODERATION_UNAVAILABLE"] };
  }
}

async function classifyInBackground(env: Env, airplaneId: string, message: string) {
  try {
    const result = await env.AI.run(CLASSIFICATION_MODEL, {
      messages: [
        {
          role: "system",
          content: "Classify a short letter. Return ONLY compact JSON with keys language (pt or en), mood (kind, hopeful, sad, happy, neutral), theme (friendship, encouragement, daily_life, culture, other). Never rewrite or answer the letter.",
        },
        { role: "user", content: message },
      ],
    }) as { response?: string } | string;
    const output = modelText(result);
    const start = output.indexOf("{");
    const end = output.lastIndexOf("}");
    if (start < 0 || end <= start) return;
    const parsed = JSON.parse(output.slice(start, end + 1)) as Record<string, unknown>;
    const language = parsed.language === "en" ? "en" : parsed.language === "pt" ? "pt" : null;
    const moods = ["kind", "hopeful", "sad", "happy", "neutral"];
    const themes = ["friendship", "encouragement", "daily_life", "culture", "other"];
    const mood = moods.includes(String(parsed.mood)) ? String(parsed.mood) : null;
    const theme = themes.includes(String(parsed.theme)) ? String(parsed.theme) : null;
    await env.DB.prepare(
      "UPDATE airplanes SET detected_language = COALESCE(?, detected_language), detected_mood = ?, theme_tag = ? WHERE id = ?",
    ).bind(language, mood, theme, airplaneId).run();
  } catch {
    // Classification is helpful metadata, never a delivery dependency.
  }
}

async function ensureAgeReady(uid: string, env: Env) {
  const user = await requireUser(uid, env);
  if (!user) return { user: null, response: json({ error: "PILOT_NOT_INITIALIZED", message: "Create the pilot profile first." }, 409) };
  if (user.status !== "ACTIVE") return { user, response: json({ error: "ACCOUNT_UNAVAILABLE" }, 403) };
  if (user.age_verified !== 1 || !["UNDER_18", "ADULT"].includes(user.age_band)) {
    return {
      user,
      response: json(
        { error: "AGE_VERIFICATION_REQUIRED", message: "Private and random delivery stay disabled until a trusted age check has established the correct age group." },
        403,
      ),
    };
  }
  return { user, response: null };
}

async function bootstrap(uid: string, env: Env) {
  const existing = await requireUser(uid, env);
  if (existing) return existing;
  const pilotCode = `PP-${crypto.randomUUID().replace(/-/g, "").slice(0, 8).toUpperCase()}`;
  await env.DB.prepare(
    "INSERT OR IGNORE INTO users (uid, pilot_code, pilot_name, age_band, age_verified) VALUES (?, ?, 'Piloto', 'UNVERIFIED', 0)",
  ).bind(uid, pilotCode).run();
  return requireUser(uid, env);
}

async function createAirplane(
  uid: string,
  body: Record<string, unknown>,
  env: Env,
  ctx: ExecutionContext,
  forcedRecipient?: string,
  replyToId?: string,
) {
  const message = text(body.message, 200);
  if (!message || [...message].length > 200) return json({ error: "MESSAGE_LENGTH", message: "Message must contain 1 to 200 characters." }, 400);
  const audience = forcedRecipient ? "DIRECT" : body.visibility === "PUBLIC" ? "PUBLIC" : "RANDOM";
  const language = body.language === "en" ? "en" : "pt";
  const mood = text(body.mood, 32) || null;
  const destination = text(body.destinationCountry, 2).toUpperCase() || null;
  const { user, response } = await ensureAgeReady(uid, env);
  if (response) return response;
  if (!user) return json({ error: "PILOT_NOT_INITIALIZED" }, 409);

  if (forcedRecipient) {
    const target = await requireUser(forcedRecipient, env);
    if (!target || target.status !== "ACTIVE" || target.age_verified !== 1 || target.age_band !== user.age_band) {
      return json({ error: "RECIPIENT_UNAVAILABLE" }, 403);
    }
    const blocked = await env.DB.prepare(
      "SELECT 1 AS found FROM blocks WHERE (blocker_uid = ? AND blocked_uid = ?) OR (blocker_uid = ? AND blocked_uid = ?) LIMIT 1",
    ).bind(uid, forcedRecipient, forcedRecipient, uid).first();
    if (blocked) return json({ error: "RECIPIENT_UNAVAILABLE" }, 403);
  }

  const hourlyActivity = await env.DB.prepare(
    `SELECT
       (SELECT COUNT(*) FROM airplanes WHERE sender_uid = ? AND created_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 hour')) +
       (SELECT COUNT(*) FROM public_replies WHERE sender_uid = ? AND created_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 hour')) AS count`,
  ).bind(uid, uid).first<{ count: number }>();
  if (Number(hourlyActivity?.count ?? 0) >= 10) {
    return json({ error: "RATE_LIMIT_EXCEEDED", message: "You have reached the hourly sending limit." }, 429);
  }

  const contentHash = await sha256(message.toLocaleLowerCase());
  const duplicate = await env.DB.prepare(
    "SELECT COUNT(*) AS count FROM airplanes WHERE sender_uid = ? AND content_hash = ? AND created_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 hour')",
  ).bind(uid, contentHash).first<{ count: number }>();
  if (!forcedRecipient && Number(duplicate?.count ?? 0) > 0) {
    return json({ error: "DUPLICATE_MESSAGE", message: "This text was already sent recently." }, 429);
  }

  const today = new Date().toISOString().slice(0, 10);
  if (!forcedRecipient) {
    const existingDaily = await env.DB.prepare(
      "SELECT original_planes FROM daily_limits WHERE uid = ? AND limit_date = ?",
    ).bind(uid, today).first<{ original_planes: number }>();
    if (Number(existingDaily?.original_planes ?? 0) >= 1) {
      return json({ error: "DAILY_LIMIT_REACHED", message: "One original plane can be launched per day." }, 429);
    }
  }

  const moderation = await moderate(env, message);
  if (moderation.state === "UNSAFE") {
    return json({ error: "MESSAGE_NOT_ALLOWED", categories: moderation.categories }, 422);
  }

  if (!forcedRecipient) {
    const daily = await env.DB.prepare(
      "INSERT INTO daily_limits(uid, limit_date, original_planes) VALUES (?, ?, 1) ON CONFLICT(uid, limit_date) DO UPDATE SET original_planes = original_planes + 1 WHERE original_planes < 1 RETURNING original_planes",
    ).bind(uid, today).first<{ original_planes: number }>();
    if (!daily) return json({ error: "DAILY_LIMIT_REACHED", message: "One original plane can be launched per day." }, 429);
  }

  const id = uuid();
  let status: string;
  if (moderation.state === "REVIEW") status = "HELD_REVIEW";
  else if (audience === "PUBLIC") status = "DELIVERED";
  else if (forcedRecipient) status = "FLYING";
  else status = "QUEUED";

  try {
    await env.DB.prepare(
      "INSERT INTO airplanes (id, sender_uid, recipient_uid, reply_to_id, audience, message_text, message_language, mood, destination_country, sender_country_code, allow_reply, status, moderation_state, moderation_categories, content_hash, delivered_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    ).bind(
      id, uid, forcedRecipient ?? null, replyToId ?? null, audience, message, language, mood, destination,
      user.country_visible === 1 ? user.country_code : null, body.allowReply === false ? 0 : 1, status,
      moderation.state, JSON.stringify(moderation.categories), contentHash,
      audience === "PUBLIC" ? isoNow() : null,
      null,
    ).run();
  } catch (error) {
    const reason = String(error);
    if (reason.includes("PAPER_PLANE_RATE_LIMIT")) {
      return json({ error: "RATE_LIMIT_EXCEEDED", message: "You have reached the hourly sending limit." }, 429);
    }
    throw error;
  }

  if (moderation.state === "SAFE") ctx.waitUntil(classifyInBackground(env, id, message));
  if (status === "DELIVERED") {
    await env.DB.prepare("INSERT INTO public_sky (airplane_id) VALUES (?)").bind(id).run();
  } else if (status === "QUEUED") {
    await env.DELIVERY_QUEUE.send({ type: "MATCH_AIRPLANE", airplaneId: id });
  } else if (status === "FLYING") {
    await env.DELIVERY_QUEUE.send({ type: "DELIVER_AIRPLANE", airplaneId: id }, { delaySeconds: 30 });
  }

  return json({ airplane: { id, status, moderation: moderation.state }, message: status === "HELD_REVIEW" ? "Held for safety review." : "Plane accepted." }, 201);
}

async function matchAirplane(airplaneId: string, env: Env) {
  const plane = await env.DB.prepare(
    "SELECT id, sender_uid, destination_country FROM airplanes WHERE id = ? AND audience = 'RANDOM' AND status = 'QUEUED' AND moderation_state = 'SAFE'",
  ).bind(airplaneId).first<{ id: string; sender_uid: string; destination_country: string | null }>();
  if (!plane) return;

  const sender = await requireUser(plane.sender_uid, env);
  if (!sender || sender.age_verified !== 1 || !["UNDER_18", "ADULT"].includes(sender.age_band)) return;

  const recipient = await env.DB.prepare(
    `SELECT u.uid FROM users u
     WHERE u.status = 'ACTIVE' AND u.age_verified = 1 AND u.age_band = ?
       AND u.accept_random_mail = 1 AND u.uid <> ?
       AND (? IS NULL OR u.country_code = ?)
       AND NOT EXISTS (SELECT 1 FROM blocks b WHERE (b.blocker_uid = ? AND b.blocked_uid = u.uid) OR (b.blocker_uid = u.uid AND b.blocked_uid = ?))
       AND NOT EXISTS (SELECT 1 FROM reports r WHERE r.reporter_uid = u.uid AND r.reported_uid = ? AND r.status = 'OPEN')
     ORDER BY COALESCE(u.last_received_at, '1970-01-01T00:00:00.000Z') ASC, RANDOM()
     LIMIT 1`,
  ).bind(sender.age_band, sender.uid, plane.destination_country, plane.destination_country, sender.uid, sender.uid, sender.uid)
    .first<{ uid: string }>();
  if (!recipient) return;

  const result = await env.DB.prepare(
    "UPDATE airplanes SET recipient_uid = ?, status = 'FLYING', matched_at = ? WHERE id = ? AND status = 'QUEUED' AND recipient_uid IS NULL",
  ).bind(recipient.uid, isoNow(), airplaneId).run();
  if ((result.meta?.changes ?? 0) === 1) {
    await env.DB.prepare("UPDATE users SET last_received_at = ? WHERE uid = ?").bind(isoNow(), recipient.uid).run();
    await env.DELIVERY_QUEUE.send({ type: "DELIVER_AIRPLANE", airplaneId }, { delaySeconds: 30 });
  }
}

async function exchangeFcmAccessToken(env: Env): Promise<string | null> {
  if (!env.FCM_SERVICE_ACCOUNT_JSON) return null;
  try {
    const account = JSON.parse(env.FCM_SERVICE_ACCOUNT_JSON) as { client_email: string; private_key: string; project_id: string };
    const key = await importPKCS8(account.private_key.replace(/\\n/g, "\n"), "RS256");
    const assertion = await new SignJWT({ scope: "https://www.googleapis.com/auth/firebase.messaging" })
      .setProtectedHeader({ alg: "RS256", typ: "JWT" })
      .setIssuer(account.client_email)
      .setSubject(account.client_email)
      .setAudience("https://oauth2.googleapis.com/token")
      .setIssuedAt()
      .setExpirationTime("1h")
      .sign(key);
    const response = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
    });
    if (!response.ok) return null;
    const token = await response.json() as { access_token?: string };
    return token.access_token ?? null;
  } catch {
    return null;
  }
}

async function notifyNewPlane(uid: string, airplaneId: string, env: Env) {
  const accessToken = await exchangeFcmAccessToken(env);
  if (!accessToken) return;
  const devices = await env.DB.prepare("SELECT fcm_token FROM devices WHERE uid = ?").bind(uid).all<{ fcm_token: string }>();
  const projectId = env.FIREBASE_PROJECT_ID;
  for (const device of devices.results ?? []) {
    try {
      await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: "POST",
        headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json" },
        body: JSON.stringify({
          message: {
            token: device.fcm_token,
            notification: { title: "Chegou um novo avião", body: "Uma mensagem está à tua espera." },
            data: { type: "NEW_PLANE", airplaneId },
            android: { priority: "HIGH" },
          },
        }),
      });
    } catch {
      // Push is best-effort; delivery is recorded in D1 independently.
    }
  }
}

async function deliverAirplane(airplaneId: string, env: Env) {
  const plane = await env.DB.prepare(
    "SELECT id, recipient_uid FROM airplanes WHERE id = ? AND status = 'FLYING' AND recipient_uid IS NOT NULL",
  ).bind(airplaneId).first<{ id: string; recipient_uid: string }>();
  if (!plane) return;
  const deliveredAt = isoNow();
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  const result = await env.DB.prepare(
    "UPDATE airplanes SET status = 'DELIVERED', delivered_at = ?, expires_at = ? WHERE id = ? AND status = 'FLYING'",
  ).bind(deliveredAt, expiresAt, airplaneId).run();
  if ((result.meta?.changes ?? 0) !== 1) return;
  await env.DB.prepare(
    "INSERT OR IGNORE INTO inbox(airplane_id, recipient_uid) VALUES (?, ?)",
  ).bind(airplaneId, plane.recipient_uid).run();
  await notifyNewPlane(plane.recipient_uid, airplaneId, env);
}

async function translateMessage(airplaneId: string, targetLanguage: "pt" | "en", message: string, env: Env): Promise<string | null> {
  const cached = await env.DB.prepare(
    "SELECT translated_text FROM translations WHERE airplane_id = ? AND target_language = ?",
  ).bind(airplaneId, targetLanguage).first<{ translated_text: string }>();
  if (cached) return cached.translated_text;

  try {
    const result = await env.AI.run(TRANSLATION_MODEL, {
      messages: [
        { role: "system", content: `Translate the user's letter into ${targetLanguage === "pt" ? "Portuguese" : "English"}. Return only the translation. Preserve meaning and tone. Do not reply, add details, or identify the sender.` },
        { role: "user", content: message },
      ],
    }) as { response?: string } | string;
    const translated = text(modelText(result), 2000);
    if (!translated) return null;
    await env.DB.prepare(
      "INSERT OR REPLACE INTO translations(airplane_id, target_language, translated_text) VALUES (?, ?, ?)",
    ).bind(airplaneId, targetLanguage, translated).run();
    return translated;
  } catch {
    return null;
  }
}

async function handleApi(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  const url = new URL(request.url);
  const method = request.method.toUpperCase();
  const path = url.pathname.replace(/\/+$/, "") || "/";

  if (method === "GET" && path === "/v1/health") {
    return json({ ok: true, service: "paper-plane-api", database: "configured", ai: "configured", time: isoNow() });
  }

  const uid = await authenticate(request, env);
  if (!uid) return json({ error: "UNAUTHORIZED", message: "A valid Firebase ID token is required." }, 401);

  const pilotOnRoute = await requireUser(uid, env);
  if (path !== "/v1/users/bootstrap" && !pilotOnRoute) {
    return json({ error: "PILOT_NOT_INITIALIZED", message: "Create the pilot profile first." }, 409);
  }
  if (pilotOnRoute && pilotOnRoute.status !== "ACTIVE") {
    return json({ error: "ACCOUNT_UNAVAILABLE" }, 403);
  }

  const admins = (env.ADMIN_UIDS ?? "").split(",").map((value) => value.trim()).filter(Boolean);
  const isAdmin = admins.includes(uid);

  if (path === "/v1/admin/reports" && method === "GET") {
    if (!isAdmin) return json({ error: "FORBIDDEN" }, 403);
    const rows = await env.DB.prepare(
      `SELECT r.id, r.reporter_uid, r.airplane_id, r.reported_uid, r.reason, r.details, r.status, r.created_at,
              a.message_text, a.audience, a.moderation_state
       FROM reports r
       LEFT JOIN airplanes a ON a.id = r.airplane_id
       WHERE r.status IN ('OPEN','IN_REVIEW')
       ORDER BY r.created_at ASC LIMIT 200`,
    ).all();
    return json({ items: rows.results ?? [] });
  }

  const adminReportMatch = path.match(/^\\/v1\\/admin\\/reports\\/([^/]+)$/);
  if (adminReportMatch && method === "POST") {
    if (!isAdmin) return json({ error: "FORBIDDEN" }, 403);
    const body = await request.json().catch(() => ({})) as Record<string, unknown>;
    const action = body.action;
    const report = await env.DB.prepare(
      "SELECT id, reported_uid FROM reports WHERE id = ? AND status IN ('OPEN','IN_REVIEW')",
    ).bind(adminReportMatch[1]).first<{ id: string; reported_uid: string | null }>();
    if (!report) return json({ error: "NOT_FOUND" }, 404);

    if (action === "dismiss" || action === "actioned") {
      await env.DB.prepare("UPDATE reports SET status = ? WHERE id = ?")
        .bind(action === "dismiss" ? "DISMISSED" : "ACTIONED", report.id).run();
      return json({ ok: true, status: action === "dismiss" ? "DISMISSED" : "ACTIONED" });
    }

    if (action === "suspend_user") {
      if (!report.reported_uid) return json({ error: "REPORTED_USER_UNAVAILABLE" }, 409);
      await env.DB.batch([
        env.DB.prepare("UPDATE users SET status = 'SUSPENDED', accept_random_mail = 0, updated_at = ? WHERE uid = ?")
          .bind(isoNow(), report.reported_uid),
        env.DB.prepare("UPDATE airplanes SET status = 'REJECTED', moderation_state = 'UNSAFE' WHERE sender_uid = ? AND status IN ('QUEUED','FLYING','HELD_REVIEW')")
          .bind(report.reported_uid),
        env.DB.prepare("UPDATE reports SET status = 'ACTIONED' WHERE id = ?").bind(report.id),
      ]);
      return json({ ok: true, status: "SUSPENDED" });
    }

    return json({ error: "INVALID_ACTION" }, 400);
  }

  if (path === "/v1/admin/review" && method === "GET") {
    if (!isAdmin) return json({ error: "FORBIDDEN" }, 403);
    const rows = await env.DB.prepare(
      "SELECT id, sender_uid, message_text, audience, moderation_categories, created_at FROM airplanes WHERE status = 'HELD_REVIEW' ORDER BY created_at ASC LIMIT 100",
    ).all();
    return json({ items: rows.results ?? [] });
  }

  const adminReviewMatch = path.match(/^\/v1\/admin\/review\/([^/]+)$/);
  if (adminReviewMatch && method === "POST") {
    if (!isAdmin) return json({ error: "FORBIDDEN" }, 403);
    const body = await request.json().catch(() => ({})) as Record<string, unknown>;
    const airplaneId = adminReviewMatch[1];
    const plane = await env.DB.prepare(
      "SELECT id, sender_uid, audience, status FROM airplanes WHERE id = ? AND status = 'HELD_REVIEW'",
    ).bind(airplaneId).first<{ id: string; sender_uid: string; audience: string; status: string }>();
    if (!plane) return json({ error: "NOT_FOUND" }, 404);
    if (body.action === "reject") {
      await env.DB.prepare("UPDATE airplanes SET status = 'REJECTED', moderation_state = 'UNSAFE' WHERE id = ?")
        .bind(airplaneId).run();
      return json({ ok: true, status: "REJECTED" });
    }
    if (body.action !== "approve") return json({ error: "INVALID_ACTION" }, 400);
    const sender = await requireUser(plane.sender_uid, env);
    if (!sender || sender.age_verified !== 1 || !["UNDER_18", "ADULT"].includes(sender.age_band)) {
      return json({ error: "AGE_VERIFICATION_REQUIRED" }, 403);
    }
    const nextStatus = plane.audience === "PUBLIC" ? "DELIVERED" : "QUEUED";
    await env.DB.prepare(
      "UPDATE airplanes SET moderation_state = 'SAFE', status = ?, delivered_at = CASE WHEN ? = 'DELIVERED' THEN ? ELSE delivered_at END WHERE id = ? AND status = 'HELD_REVIEW'",
    ).bind(nextStatus, nextStatus, isoNow(), airplaneId).run();
    if (nextStatus === "DELIVERED") {
      await env.DB.prepare("INSERT OR IGNORE INTO public_sky(airplane_id) VALUES (?)").bind(airplaneId).run();
    } else {
      await env.DELIVERY_QUEUE.send({ type: "MATCH_AIRPLANE", airplaneId });
    }
    return json({ ok: true, status: nextStatus });
  }

  if (method === "POST" && path === "/v1/users/bootstrap") {
    const user = await bootstrap(uid, env);
    return json({ pilot: user, canSend: user?.age_verified === 1 });
  }

  if (method === "GET" && path === "/v1/profile") {
    const user = await requireUser(uid, env);
    if (!user) return json({ error: "PILOT_NOT_INITIALIZED" }, 409);
    const stats = await env.DB.prepare(
      "SELECT COUNT(*) AS sent FROM airplanes WHERE sender_uid = ? AND status <> 'REJECTED'",
    ).bind(uid).first<{ sent: number }>();
    const received = await env.DB.prepare(
      "SELECT COUNT(*) AS received FROM inbox WHERE recipient_uid = ?",
    ).bind(uid).first<{ received: number }>();
    return json({ pilot: user, stats: { sent: stats?.sent ?? 0, received: received?.received ?? 0 } });
  }

  if (method === "POST" && path === "/v1/airplanes") {
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    if (!body) return json({ error: "INVALID_JSON" }, 400);
    return createAirplane(uid, body, env, ctx);
  }

  if (method === "GET" && path === "/v1/inbox") {
    const rows = await env.DB.prepare(
      `SELECT a.id, a.message_text, a.message_language, a.mood, a.status, a.delivered_at,
              a.expires_at, a.sender_country_code, a.allow_reply
       FROM inbox i JOIN airplanes a ON a.id = i.airplane_id
       WHERE i.recipient_uid = ? AND a.status IN ('DELIVERED','READ','RESPONDED')
       ORDER BY a.delivered_at DESC LIMIT 100`,
    ).bind(uid).all();
    return json({ items: rows.results ?? [] });
  }

  if (method === "GET" && path.startsWith("/v1/inbox/")) {
    const airplaneId = path.split("/").at(-1)!;
    const plane = await env.DB.prepare(
      `SELECT a.* FROM inbox i JOIN airplanes a ON a.id = i.airplane_id
       WHERE i.recipient_uid = ? AND a.id = ? LIMIT 1`,
    ).bind(uid, airplaneId).first<Record<string, unknown>>();
    if (!plane) return json({ error: "NOT_FOUND" }, 404);
    if (plane.status === "DELIVERED") {
      const now = isoNow();
      await env.DB.batch([
        env.DB.prepare("UPDATE airplanes SET status = 'READ', read_at = ?, expires_at = ? WHERE id = ? AND status = 'DELIVERED'")
          .bind(now, new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString(), airplaneId),
        env.DB.prepare("UPDATE inbox SET opened_at = ? WHERE airplane_id = ? AND recipient_uid = ?")
          .bind(now, airplaneId, uid),
      ]);
      plane.status = "READ";
    }
    return json({ airplane: plane });
  }

  if (method === "GET" && path === "/v1/airplanes/sent") {
    const rows = await env.DB.prepare(
      "SELECT id, audience, status, destination_country, created_at, delivered_at, read_at FROM airplanes WHERE sender_uid = ? ORDER BY created_at DESC LIMIT 100",
    ).bind(uid).all();
    return json({ items: rows.results ?? [] });
  }

  const releaseMatch = path.match(/^\/v1\/airplanes\/([^/]+)\/release$/);
  if (method === "POST" && releaseMatch) {
    const result = await env.DB.prepare(
      "UPDATE airplanes SET status = 'RELEASED' WHERE id = ? AND recipient_uid = ? AND status IN ('DELIVERED','READ')",
    ).bind(releaseMatch[1], uid).run();
    if ((result.meta?.changes ?? 0) !== 1) return json({ error: "NOT_FOUND_OR_ALREADY_CLOSED" }, 404);
    return json({ ok: true, status: "RELEASED" });
  }

  const privateReplyMatch = path.match(/^\/v1\/airplanes\/([^/]+)\/reply$/);
  if (method === "POST" && privateReplyMatch) {
    const original = await env.DB.prepare(
      "SELECT sender_uid, recipient_uid, allow_reply, status FROM airplanes WHERE id = ?",
    ).bind(privateReplyMatch[1]).first<{ sender_uid: string; recipient_uid: string | null; allow_reply: number; status: string }>();
    if (!original || original.recipient_uid !== uid || original.allow_reply !== 1 || !["DELIVERED","READ"].includes(original.status)) {
      return json({ error: "REPLY_NOT_ALLOWED" }, 403);
    }
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    if (!body) return json({ error: "INVALID_JSON" }, 400);
    const replyResponse = await createAirplane(uid, body, env, ctx, original.sender_uid, privateReplyMatch[1]);
    if (replyResponse.status === 201) {
      await env.DB.prepare(
        "UPDATE airplanes SET status = 'RESPONDED' WHERE id = ? AND status IN ('DELIVERED','READ')",
      ).bind(privateReplyMatch[1]).run();
    }
    return replyResponse;
  }

  const reportMatch = path.match(/^\/v1\/airplanes\/([^/]+)\/report$/);
  if (method === "POST" && reportMatch) {
    const body = await request.json().catch(() => ({})) as Record<string, unknown>;
    const reason = text(body.reason, 60) || "OTHER";
    const id = uuid();
    await env.DB.prepare(
      "INSERT INTO reports(id, reporter_uid, airplane_id, reported_uid, reason, details) SELECT ?, ?, a.id, a.sender_uid, ?, ? FROM airplanes a WHERE a.id = ? AND a.sender_uid <> ? AND (a.recipient_uid = ? OR a.audience = 'PUBLIC')",
    ).bind(id, uid, reason, text(body.details, 500) || null, reportMatch[1], uid, uid).run();
    const created = await env.DB.prepare("SELECT id FROM reports WHERE id = ?").bind(id).first();
    if (!created) return json({ error: "NOT_FOUND" }, 404);
    return json({ ok: true, reportId: id }, 201);
  }

  const blockSenderMatch = path.match(/^\/v1\/airplanes\/([^/]+)\/block-sender$/);
  if (method === "POST" && blockSenderMatch) {
    const plane = await env.DB.prepare(
      "SELECT sender_uid FROM airplanes WHERE id = ? AND (recipient_uid = ? OR audience = 'PUBLIC')",
    ).bind(blockSenderMatch[1], uid).first<{ sender_uid: string }>();
    if (!plane || plane.sender_uid === uid) return json({ error: "NOT_FOUND" }, 404);
    await env.DB.prepare("INSERT OR IGNORE INTO blocks(blocker_uid, blocked_uid) VALUES (?, ?)")
      .bind(uid, plane.sender_uid).run();
    return json({ ok: true });
  }

  if (method === "POST" && path === "/v1/users/block") {
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    const blockedUid = text(body?.uid, 128);
    if (!blockedUid || blockedUid === uid) return json({ error: "INVALID_USER" }, 400);
    const target = await requireUser(blockedUid, env);
    if (!target) return json({ error: "USER_NOT_FOUND" }, 404);
    await env.DB.prepare("INSERT OR IGNORE INTO blocks(blocker_uid, blocked_uid) VALUES (?, ?)").bind(uid, blockedUid).run();
    return json({ ok: true });
  }

  if (method === "POST" && path === "/v1/devices/register") {
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    const token = text(body?.token, 4096);
    const platform = body?.platform === "ios" || body?.platform === "web" ? body.platform : "android";
    if (token.length < 40) return json({ error: "INVALID_DEVICE_TOKEN" }, 400);
    const id = uuid();
    await env.DB.prepare(
      "INSERT INTO devices(id, uid, fcm_token, platform) VALUES (?, ?, ?, ?) ON CONFLICT(fcm_token) DO UPDATE SET uid = excluded.uid, platform = excluded.platform, updated_at = ?",
    ).bind(id, uid, token, platform, isoNow()).run();
    return json({ ok: true }, 201);
  }

  if (method === "GET" && path === "/v1/open-sky") {
    const rows = await env.DB.prepare(
      `SELECT a.id, a.message_text, a.message_language, a.mood, a.sender_country_code, a.created_at, p.likes_count,
              (SELECT COUNT(*) FROM public_replies r WHERE r.airplane_id = a.id AND r.moderation_state = 'SAFE') AS replies_count
       FROM public_sky p JOIN airplanes a ON a.id = p.airplane_id
       WHERE a.audience = 'PUBLIC' AND a.moderation_state = 'SAFE' AND a.status = 'DELIVERED'
       ORDER BY a.created_at DESC LIMIT 50`,
    ).all();
    return json({ items: rows.results ?? [] });
  }

  const likeMatch = path.match(/^\/v1\/open-sky\/([^/]+)\/like$/);
  if (method === "POST" && likeMatch) {
    const id = likeMatch[1];
    const inserted = await env.DB.prepare("INSERT OR IGNORE INTO public_likes(airplane_id, uid) SELECT ?, ? WHERE EXISTS (SELECT 1 FROM public_sky WHERE airplane_id = ?)")
      .bind(id, uid, id).run();
    if ((inserted.meta?.changes ?? 0) === 0) return json({ error: "NOT_FOUND_OR_ALREADY_LIKED" }, 404);
    await env.DB.prepare("UPDATE public_sky SET likes_count = likes_count + 1 WHERE airplane_id = ?").bind(id).run();
    return json({ ok: true });
  }

  const publicRepliesMatch = path.match(/^\/v1\/open-sky\/([^/]+)\/replies$/);
  if (publicRepliesMatch && method === "GET") {
    const rows = await env.DB.prepare(
      "SELECT id, message_text, created_at FROM public_replies WHERE airplane_id = ? AND moderation_state = 'SAFE' ORDER BY created_at ASC LIMIT 5",
    ).bind(publicRepliesMatch[1]).all();
    return json({ items: rows.results ?? [] });
  }
  if (publicRepliesMatch && method === "POST") {
    const { user, response } = await ensureAgeReady(uid, env);
    if (response) return response;
    if (!user) return json({ error: "PILOT_NOT_INITIALIZED" }, 409);
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    const message = text(body?.message, 200);
    if (!message) return json({ error: "MESSAGE_LENGTH" }, 400);
    const parent = await env.DB.prepare("SELECT id FROM public_sky WHERE airplane_id = ?").bind(publicRepliesMatch[1]).first();
    if (!parent) return json({ error: "NOT_FOUND" }, 404);
    const hourlyActivity = await env.DB.prepare(
      `SELECT
         (SELECT COUNT(*) FROM airplanes WHERE sender_uid = ? AND created_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 hour')) +
         (SELECT COUNT(*) FROM public_replies WHERE sender_uid = ? AND created_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 hour')) AS count`,
    ).bind(uid, uid).first<{ count: number }>();
    if (Number(hourlyActivity?.count ?? 0) >= 10) return json({ error: "RATE_LIMIT_EXCEEDED" }, 429);
    const count = await env.DB.prepare("SELECT COUNT(*) AS count FROM public_replies WHERE airplane_id = ?").bind(publicRepliesMatch[1]).first<{ count: number }>();
    if (Number(count?.count ?? 0) >= 5) return json({ error: "REPLY_LIMIT_REACHED" }, 429);
    const moderation = await moderate(env, message);
    if (moderation.state !== "SAFE") return json({ error: moderation.state === "UNSAFE" ? "MESSAGE_NOT_ALLOWED" : "HELD_FOR_REVIEW" }, 422);
    const id = uuid();
    try {
      await env.DB.prepare("INSERT INTO public_replies(id, airplane_id, sender_uid, message_text, moderation_state) VALUES (?, ?, ?, ?, 'SAFE')")
        .bind(id, publicRepliesMatch[1], uid, message).run();
    } catch (error) {
      const reason = String(error);
      if (reason.includes("PAPER_PLANE_RATE_LIMIT")) return json({ error: "RATE_LIMIT_EXCEEDED" }, 429);
      if (reason.includes("PUBLIC_REPLY_LIMIT_REACHED")) return json({ error: "REPLY_LIMIT_REACHED" }, 429);
      throw error;
    }
    return json({ id, status: "PUBLISHED" }, 201);
  }

  const translationMatch = path.match(/^\/v1\/airplanes\/([^/]+)\/translation$/);
  if (method === "POST" && translationMatch) {
    const body = await request.json().catch(() => ({})) as Record<string, unknown>;
    const target = body.language === "en" ? "en" : "pt";
    const plane = await env.DB.prepare(
      "SELECT message_text, sender_uid, recipient_uid, moderation_state FROM airplanes WHERE id = ?",
    ).bind(translationMatch[1]).first<{ message_text: string; sender_uid: string; recipient_uid: string | null; moderation_state: string }>();
    if (!plane || (plane.sender_uid !== uid && plane.recipient_uid !== uid) || plane.moderation_state !== "SAFE") return json({ error: "NOT_FOUND" }, 404);
    const translated = await translateMessage(translationMatch[1], target, plane.message_text, env);
    if (!translated) return json({ error: "TRANSLATION_UNAVAILABLE" }, 503);
    return json({ text: translated, language: target });
  }

  return json({ error: "NOT_FOUND" }, 404);
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const cors = corsHeaders(request, env);
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    try {
      const response = await handleApi(request, env, ctx);
      const headers = new Headers(response.headers);
      for (const [key, value] of Object.entries(cors)) headers.set(key, value);
      return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
    } catch {
      return json({ error: "INTERNAL_ERROR", message: "The request could not be completed." }, 500, cors);
    }
  },

  async queue(batch: QueueBatch<DeliveryJob>, env: Env): Promise<void> {
    for (const message of batch.messages) {
      try {
        if (message.body.type === "MATCH_AIRPLANE") await matchAirplane(message.body.airplaneId, env);
        if (message.body.type === "DELIVER_AIRPLANE") await deliverAirplane(message.body.airplaneId, env);
        message.ack();
      } catch {
        message.retry({ delaySeconds: 60 });
      }
    }
  },

  async scheduled(_controller: ScheduledController, env: Env, _ctx: ExecutionContext): Promise<void> {
    // Revisit queued planes every five minutes; unmatched planes remain queued, never falsely marked delivered.
    const queued = await env.DB.prepare(
      "SELECT id FROM airplanes WHERE status = 'QUEUED' AND moderation_state = 'SAFE' ORDER BY created_at ASC LIMIT 20",
    ).all<{ id: string }>();
    for (const plane of queued.results ?? []) {
      await matchAirplane(plane.id, env);
    }

    // Expire unread mail after 24 hours and opened mail 48 hours after it was opened.
    await env.DB.prepare(
      "UPDATE airplanes SET status = 'EXPIRED' WHERE status IN ('DELIVERED','READ') AND expires_at IS NOT NULL AND expires_at <= ?",
    ).bind(isoNow()).run();
  },
};
