import { createRemoteJWKSet, jwtVerify, importPKCS8, SignJWT } from "jose";
import { COUNTRY_CENTROIDS } from "./country_centroids";

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
    "SELECT uid, pilot_code, pilot_name, pilot_handle, birth_year, declared_age_band, age_declaration_at, profile_completed, language, country_code, country_visible, status, age_band, age_verified, accept_random_mail, push_enabled FROM users WHERE uid = ?",
  ).bind(uid).first<{
    uid: string; pilot_code: string; pilot_name: string; pilot_handle: string | null;
    birth_year: number | null; declared_age_band: string; age_declaration_at: string | null;
    profile_completed: number; language: string; country_code: string | null;
    country_visible: number; status: string; age_band: string; age_verified: number;
    accept_random_mail: number; push_enabled: number;
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


function normalizePilotHandle(value: unknown): string {
  return text(value, 32).replace(/^@/, "").toLowerCase();
}
function isValidPilotHandle(value: string): boolean {
  return value.length >= 4 && value.length <= 28 &&
    /^[a-z0-9]+(?:_[a-z0-9]+)*(?:-[0-9]{2})?$/.test(value);
}
function buildFlightPlan(originCode: string | null, destinationCode: string | null) {
  if (!originCode || !destinationCode) return null;
  const origin = COUNTRY_CENTROIDS[originCode.toUpperCase()];
  const destination = COUNTRY_CENTROIDS[destinationCode.toUpperCase()];
  if (!origin || !destination) return null;
  const rad = (v: number) => v * Math.PI / 180;
  const deg = (v: number) => v * 180 / Math.PI;
  const lat1 = rad(origin.lat), lat2 = rad(destination.lat);
  const dLat = lat2 - lat1, dLng = rad(destination.lng - origin.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  const distanceKm = Math.round(6371.0088 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h)));
  const vector = (lat: number, lng: number) => {
    const p = rad(lat), l = rad(lng);
    return [Math.cos(p) * Math.cos(l), Math.cos(p) * Math.sin(l), Math.sin(p)];
  };
  const a = vector(origin.lat, origin.lng), b = vector(destination.lat, destination.lng);
  const dot = Math.max(-1, Math.min(1, a[0] * b[0] + a[1] * b[1] + a[2] * b[2]));
  const omega = Math.acos(dot), sinOmega = Math.sin(omega);
  const points: Array<{ lat: number; lng: number }> = [];
  for (let step = 0; step <= 40; step++) {
    const t = step / 40;
    const left = sinOmega < 1e-8 ? 1 - t : Math.sin((1 - t) * omega) / sinOmega;
    const right = sinOmega < 1e-8 ? t : Math.sin(t * omega) / sinOmega;
    const x = left * a[0] + right * b[0];
    const y = left * a[1] + right * b[1];
    const z = left * a[2] + right * b[2];
    points.push({
      lat: Number(deg(Math.atan2(z, Math.sqrt(x * x + y * y))).toFixed(5)),
      lng: Number(deg(Math.atan2(y, x)).toFixed(5)),
    });
  }
  // Symbolic app journey, not GPS or physical-aircraft telemetry.
  const durationSeconds = Math.max(5 * 60 * 60, Math.ceil(distanceKm / 900 * 60 * 60));
  const startedAt = isoNow();
  return {
    distanceKm,
    durationSeconds,
    startedAt,
    arrivalAt: new Date(Date.now() + durationSeconds * 1000).toISOString(),
    routeJson: JSON.stringify({
      originCountry: originCode.toUpperCase(),
      destinationCountry: destinationCode.toUpperCase(),
      origin: { lat: origin.lat, lng: origin.lng },
      destination: { lat: destination.lat, lng: destination.lng },
      points,
    }),
  };
}
async function chooseEligiblePilot(
  env: Env,
  candidates: Array<{ uid: string; country_code: string; language: string }>,
  preferences: { destinationCountry: string | null; messageLanguage: string },
) {
  if (candidates.length <= 1) return candidates[0] ?? null;
  try {
    const result = await env.AI.run(CLASSIFICATION_MODEL, {
      messages: [
        {
          role: "system",
          content: "Choose one candidate for a symbolic paper-plane journey. All candidates passed server-side age-band, consent, account, blocking and safety checks. Prefer the requested destination country if present; otherwise consider language compatibility and geographic diversity. Return ONLY JSON: { \"candidate_index\": integer }. Never invent an index or a person.",
        },
        {
          role: "user",
          content: JSON.stringify({
            destinationCountry: preferences.destinationCountry,
            messageLanguage: preferences.messageLanguage,
            candidates: candidates.map((candidate, index) => ({
              candidate_index: index,
              country: candidate.country_code,
              language: candidate.language,
            })),
          }),
        },
      ],
    });
    const output = modelText(result);
    const start = output.indexOf("{"), end = output.lastIndexOf("}");
    if (start >= 0 && end > start) {
      const parsed = JSON.parse(output.slice(start, end + 1)) as { candidate_index?: unknown };
      const index = Number(parsed.candidate_index);
      if (Number.isInteger(index) && index >= 0 && index < candidates.length) return candidates[index];
    }
  } catch {
    // Database fairness order is the safe fallback when Workers AI is unavailable.
  }
  return candidates[0];
}
function flightProgress(startedAt: string | null, arrivalAt: string | null, status: string) {
  if (["DELIVERED", "READ", "RESPONDED"].includes(status)) return 1;
  if (!startedAt || !arrivalAt) return 0;
  const start = Date.parse(startedAt), arrival = Date.parse(arrivalAt);
  if (!Number.isFinite(start) || !Number.isFinite(arrival) || arrival <= start) return 0;
  return Math.max(0, Math.min(0.999, (Date.now() - start) / (arrival - start)));
}

async function ensurePilotReady(uid: string, env: Env) {
  const user = await requireUser(uid, env);
  if (!user) return { user: null, response: json({ error: "PILOT_NOT_INITIALIZED", message: "Create the pilot profile first." }, 409) };
  if (user.status !== "ACTIVE") return { user, response: json({ error: "ACCOUNT_UNAVAILABLE" }, 403) };
  if (user.profile_completed !== 1 || !user.country_code) {
    return { user, response: json({ error: "PROFILE_SETUP_REQUIRED", message: "Complete your pilot profile and choose a country before sending." }, 409) };
  }
  if (!["UNDER_18", "ADULT"].includes(user.declared_age_band)) {
    return { user, response: json({ error: "AGE_DECLARATION_REQUIRED", message: "Add your date of birth to your profile before sending." }, 409) };
  }
  return { user, response: null };
}

async function bootstrap(uid: string, env: Env) {
  const existing = await requireUser(uid, env);
  if (existing) return existing;
  const pilotCode = `PP-${crypto.randomUUID().replace(/-/g, "").slice(0, 8).toUpperCase()}`;
  await env.DB.prepare(
    "INSERT OR IGNORE INTO users (uid, pilot_code, pilot_name, age_band, age_verified, profile_completed, push_enabled) VALUES (?, ?, 'Piloto', 'UNVERIFIED', 0, 0, 0)",
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
  const requestedPlaneModel = text(body.planeModel, 16).toUpperCase() || "DART";
  if (!["DART", "GLIDER", "SWALLOW"].includes(requestedPlaneModel)) {
    return json({ error: "INVALID_PLANE_MODEL" }, 400);
  }
  const destination = text(body.destinationCountry, 2).toUpperCase() || null;
  const { user, response } = await ensurePilotReady(uid, env);
  if (response) return response;
  if (!user) return json({ error: "PILOT_NOT_INITIALIZED" }, 409);

  let directFlight: ReturnType<typeof buildFlightPlan> = null;
  if (forcedRecipient) {
    const targetUser = await requireUser(forcedRecipient, env);
    if (!targetUser || targetUser.status !== "ACTIVE" ||
        targetUser.declared_age_band !== user.declared_age_band ||
        !["UNDER_18", "ADULT"].includes(targetUser.declared_age_band) ||
        targetUser.profile_completed !== 1) {
      return json({ error: "RECIPIENT_UNAVAILABLE" }, 403);
    }
    directFlight = buildFlightPlan(user.country_code, targetUser.country_code);
    if (!directFlight) return json({ error: "ROUTE_UNAVAILABLE" }, 409);
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
      "INSERT INTO airplanes (id, sender_uid, recipient_uid, reply_to_id, audience, message_text, message_language, mood, destination_country, sender_country_code, allow_reply, status, moderation_state, moderation_categories, content_hash, delivered_at, expires_at, plane_model) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    ).bind(
      id, uid, forcedRecipient ?? null, replyToId ?? null, audience, message, language, mood, destination,
      user.country_visible === 1 ? user.country_code : null, body.allowReply === false ? 0 : 1, status,
      moderation.state, JSON.stringify(moderation.categories), contentHash,
      audience === "PUBLIC" ? isoNow() : null,
      null,
      requestedPlaneModel,
    ).run();
  } catch (error) {
    const reason = String(error);
    if (reason.includes("PAPER_PLANE_RATE_LIMIT")) {
      return json({ error: "RATE_LIMIT_EXCEEDED", message: "You have reached the hourly sending limit." }, 429);
    }
    throw error;
  }

  await env.DB.prepare(
    "UPDATE onboarding_first_flights SET state = 'LAUNCHED', updated_at = ? WHERE uid = ? AND state = 'READY_TO_LAUNCH'",
  ).bind(isoNow(), uid).run();

  if (moderation.state === "SAFE") ctx.waitUntil(classifyInBackground(env, id, message));
  if (directFlight && status === "FLYING") {
    await env.DB.prepare(
      "UPDATE airplanes SET flight_distance_km = ?, flight_duration_seconds = ?, flight_started_at = ?, estimated_arrival_at = ?, route_json = ? WHERE id = ?",
    ).bind(directFlight.distanceKm, directFlight.durationSeconds, directFlight.startedAt, directFlight.arrivalAt, directFlight.routeJson, id).run();
  }
  if (status === "DELIVERED") {
    await env.DB.prepare("INSERT INTO public_sky (airplane_id) VALUES (?)").bind(id).run();
  } else if (status === "QUEUED") {
    await env.DELIVERY_QUEUE.send({ type: "MATCH_AIRPLANE", airplaneId: id });
  }

  if (body.firstFlight === true) {
    await env.DB.prepare(
      "UPDATE onboarding_first_flights SET state = 'LAUNCHED', updated_at = ? WHERE uid = ?",
    ).bind(isoNow(), uid).run();
  }

  return json(
    { airplane: { id, status, moderation: moderation.state }, message: status === "HELD_REVIEW" ? "Held for safety review." : "Plane accepted." },
    status === "HELD_REVIEW" ? 202 : 201,
  );
}

async function matchAirplane(airplaneId: string, env: Env) {
  const plane = await env.DB.prepare(
    "SELECT id, sender_uid, destination_country, message_language FROM airplanes WHERE id = ? AND audience = 'RANDOM' AND status = 'QUEUED' AND moderation_state = 'SAFE'",
  ).bind(airplaneId).first<{ id: string; sender_uid: string; destination_country: string | null; message_language: string }>();
  if (!plane) return;

  const sender = await requireUser(plane.sender_uid, env);
  if (!sender || sender.profile_completed !== 1 || !sender.country_code ||
      !["UNDER_18", "ADULT"].includes(sender.declared_age_band)) return;

  const candidateRows = await env.DB.prepare(
    `SELECT u.uid, u.country_code, u.language
     FROM users u
     WHERE u.status = 'ACTIVE' AND u.profile_completed = 1 AND u.country_code IS NOT NULL
       AND u.declared_age_band = ?
       AND u.accept_random_mail = 1 AND u.uid <> ?
       AND NOT EXISTS (SELECT 1 FROM blocks b WHERE (b.blocker_uid = ? AND b.blocked_uid = u.uid) OR (b.blocker_uid = u.uid AND b.blocked_uid = ?))
       AND NOT EXISTS (SELECT 1 FROM reports r WHERE r.reporter_uid = u.uid AND r.reported_uid = ? AND r.status = 'OPEN')
     ORDER BY CASE WHEN ? IS NOT NULL AND u.country_code = ? THEN 0 ELSE 1 END,
       COALESCE(u.last_received_at, '1970-01-01T00:00:00.000Z') ASC,
       RANDOM()
     LIMIT 40`,
  ).bind(sender.declared_age_band, sender.uid, sender.uid, sender.uid, sender.uid, plane.destination_country, plane.destination_country)
    .all<{ uid: string; country_code: string; language: string }>();
  const candidates = candidateRows.results ?? [];
  if (candidates.length === 0) return;

  // Workers AI chooses only inside this server-filtered eligible set.
  // No account identifier or message content is sent to the model.
  const recipient = await chooseEligiblePilot(env, candidates, {
    destinationCountry: plane.destination_country,
    messageLanguage: plane.message_language,
  });
  if (!recipient) return;
  const route = buildFlightPlan(sender.country_code, recipient.country_code);
  if (!route) return;

  const matchedAt = isoNow();
  const result = await env.DB.prepare(
    "UPDATE airplanes SET recipient_uid = ?, status = 'FLYING', matched_at = ?, flight_distance_km = ?, flight_duration_seconds = ?, flight_started_at = ?, estimated_arrival_at = ?, route_json = ? WHERE id = ? AND status = 'QUEUED' AND recipient_uid IS NULL",
  ).bind(recipient.uid, matchedAt, route.distanceKm, route.durationSeconds, route.startedAt, route.arrivalAt, route.routeJson, airplaneId).run();
  if ((result.meta?.changes ?? 0) === 1) {
    await env.DB.prepare("UPDATE users SET last_received_at = ? WHERE uid = ?").bind(matchedAt, recipient.uid).run();
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
  const devices = await env.DB.prepare("SELECT d.fcm_token FROM devices d JOIN users u ON u.uid = d.uid WHERE d.uid = ? AND u.push_enabled = 1 AND u.status = 'ACTIVE'").bind(uid).all<{ fcm_token: string }>();
  const projectId = env.FIREBASE_PROJECT_ID;
  for (const device of devices.results ?? []) {
    try {
      const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
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
      if (response.status === 404) {
        const failure = await response.json().catch(() => ({})) as {
          error?: { details?: Array<{ errorCode?: string }> };
        };
        const errorCode = failure.error?.details?.find((detail) => detail.errorCode)?.errorCode;
        if (errorCode === "UNREGISTERED") {
          await env.DB.prepare("DELETE FROM devices WHERE uid = ? AND fcm_token = ?")
            .bind(uid, device.fcm_token).run();
        }
      }
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

  if (method === "GET" && path === "/v1/age-verification/return") {
    return new Response(
      `<!doctype html><html lang="pt"><meta name="viewport" content="width=device-width,initial-scale=1">
      <title>Paper Plane · Verificação concluída</title>
      <body style="margin:0;background:#071225;color:#f4f0e7;font:16px system-ui;display:grid;min-height:100vh;place-items:center">
      <main style="max-width:420px;padding:32px;text-align:center">
      <div style="font-size:52px">✈️</div><h1 style="color:#ffe7a8">Etapa concluída</h1>
      <p style="line-height:1.6;color:#c6d2e5">Regressa ao Paper Plane. A aplicação vai consultar o resultado diretamente no servidor.</p>
      <p style="font-size:13px;color:#94a3b8">Não feches a sessão da tua conta. Podes voltar ao aplicativo agora.</p>
      </main></body></html>`,
      { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" } },
    );
  }

  if (method === "GET" && path === "/v1/health") {
    try {
      await env.DB.prepare("SELECT 1 AS ready").first<{ ready: number }>();
      return json({
        ok: true,
        service: "paper-plane-api",
        database: "connected",
        ai: env.AI ? "binding_available" : "unavailable",
        integrations: {
          androidPush: env.FCM_SERVICE_ACCOUNT_JSON ? "configured" : "needs_configuration",
        },
        time: isoNow(),
      });
    } catch {
      return json({ ok: false, service: "paper-plane-api", database: "unavailable", time: isoNow() }, 503);
    }
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

  const adminReportMatch = path.match(/^\/v1\/admin\/reports\/([^/]+)$/);
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

  if (path === "/v1/admin/support" && method === "GET") {
    if (!isAdmin) return json({ error: "FORBIDDEN" }, 403);
    const rows = await env.DB.prepare(
      `SELECT t.id, t.uid, u.pilot_handle, t.category, t.subject, t.details, t.status, t.created_at, t.updated_at
       FROM support_tickets t
       JOIN users u ON u.uid = t.uid
       WHERE t.status IN ('OPEN','IN_REVIEW')
       ORDER BY CASE t.category WHEN 'SAFETY' THEN 0 ELSE 1 END, t.created_at ASC
       LIMIT 200`,
    ).all();
    return json({ items: rows.results ?? [] });
  }

  const adminSupportMatch = path.match(/^\/v1\/admin\/support\/([^/]+)$/);
  if (adminSupportMatch && method === "POST") {
    if (!isAdmin) return json({ error: "FORBIDDEN" }, 403);
    const body = await request.json().catch(() => ({})) as Record<string, unknown>;
    const action = body.action;
    const status = action === "in_review" ? "IN_REVIEW"
      : action === "resolve" ? "RESOLVED"
      : action === "close" ? "CLOSED" : null;
    if (!status) return json({ error: "INVALID_ACTION" }, 400);
    const result = await env.DB.prepare(
      "UPDATE support_tickets SET status = ?, updated_at = ? WHERE id = ? AND status IN ('OPEN','IN_REVIEW')",
    ).bind(status, isoNow(), adminSupportMatch[1]).run();
    if ((result.meta?.changes ?? 0) !== 1) return json({ error: "NOT_FOUND_OR_ALREADY_CLOSED" }, 404);
    await env.DB.prepare(
      "INSERT INTO audit_events(id, actor_uid, event_type, entity_id, metadata_json) VALUES (?, ?, 'SUPPORT_TICKET_UPDATED', ?, ?)",
    ).bind(uuid(), uid, adminSupportMatch[1], JSON.stringify({ status })).run();
    return json({ ok: true, status });
  }

  if (path === "/v1/admin/review" && method === "GET") {
    if (!isAdmin) return json({ error: "FORBIDDEN" }, 403);
    const [planes, replies] = await Promise.all([
      env.DB.prepare(
        "SELECT id, sender_uid, recipient_uid, message_text, audience, moderation_categories, created_at FROM airplanes WHERE status = 'HELD_REVIEW' ORDER BY created_at ASC LIMIT 100",
      ).all(),
      env.DB.prepare(
        "SELECT id, airplane_id, sender_uid, message_text, created_at FROM public_replies WHERE moderation_state = 'REVIEW' ORDER BY created_at ASC LIMIT 100",
      ).all(),
    ]);
    return json({ items: planes.results ?? [], replies: replies.results ?? [] });
  }

  const adminReviewMatch = path.match(/^\/v1\/admin\/review\/([^/]+)$/);
  if (adminReviewMatch && method === "POST") {
    if (!isAdmin) return json({ error: "FORBIDDEN" }, 403);
    const body = await request.json().catch(() => ({})) as Record<string, unknown>;
    const airplaneId = adminReviewMatch[1];
    const plane = await env.DB.prepare(
      "SELECT id, sender_uid, recipient_uid, reply_to_id, audience, status FROM airplanes WHERE id = ? AND status = 'HELD_REVIEW'",
    ).bind(airplaneId).first<{ id: string; sender_uid: string; recipient_uid: string | null; reply_to_id: string | null; audience: string; status: string }>();
    if (!plane) return json({ error: "NOT_FOUND" }, 404);
    if (body.action === "reject") {
      await env.DB.prepare("UPDATE airplanes SET status = 'REJECTED', moderation_state = 'UNSAFE' WHERE id = ?")
        .bind(airplaneId).run();
      return json({ ok: true, status: "REJECTED" });
    }
    if (body.action !== "approve") return json({ error: "INVALID_ACTION" }, 400);
    const sender = await requireUser(plane.sender_uid, env);
    if (!sender || !["UNDER_18", "ADULT"].includes(sender.declared_age_band)) {
      return json({ error: "AGE_DECLARATION_REQUIRED" }, 403);
    }

    let nextStatus: "DELIVERED" | "FLYING" | "QUEUED";
    if (plane.audience === "PUBLIC") {
      nextStatus = "DELIVERED";
    } else if (plane.audience === "DIRECT") {
      if (!plane.recipient_uid) return json({ error: "RECIPIENT_UNAVAILABLE" }, 409);
      const recipient = await requireUser(plane.recipient_uid, env);
      if (
        !recipient ||
        recipient.status !== "ACTIVE" ||
        !["UNDER_18", "ADULT"].includes(recipient.declared_age_band) ||
        recipient.declared_age_band !== sender.declared_age_band
      ) return json({ error: "RECIPIENT_UNAVAILABLE" }, 409);
      const blocked = await env.DB.prepare(
        "SELECT 1 AS found FROM blocks WHERE (blocker_uid = ? AND blocked_uid = ?) OR (blocker_uid = ? AND blocked_uid = ?) LIMIT 1",
      ).bind(plane.sender_uid, plane.recipient_uid, plane.recipient_uid, plane.sender_uid).first();
      if (blocked) return json({ error: "RECIPIENT_UNAVAILABLE" }, 409);
      nextStatus = "FLYING";
    } else {
      nextStatus = "QUEUED";
    }

    await env.DB.prepare(
      "UPDATE airplanes SET moderation_state = 'SAFE', status = ?, delivered_at = CASE WHEN ? = 'DELIVERED' THEN ? ELSE delivered_at END WHERE id = ? AND status = 'HELD_REVIEW'",
    ).bind(nextStatus, nextStatus, isoNow(), airplaneId).run();

    if (nextStatus === "DELIVERED") {
      await env.DB.prepare("INSERT OR IGNORE INTO public_sky(airplane_id) VALUES (?)").bind(airplaneId).run();
    } else if (nextStatus === "FLYING") {
      const sender = await requireUser(plane.sender_uid, env);
      const recipient = plane.recipient_uid ? await requireUser(plane.recipient_uid, env) : null;
      const route = buildFlightPlan(sender?.country_code ?? null, recipient?.country_code ?? null);
      if (!route || !recipient) return json({ error: "ROUTE_UNAVAILABLE" }, 409);
      await env.DB.prepare(
        "UPDATE airplanes SET flight_distance_km = ?, flight_duration_seconds = ?, flight_started_at = ?, estimated_arrival_at = ?, route_json = ? WHERE id = ?",
      ).bind(route.distanceKm, route.durationSeconds, route.startedAt, route.arrivalAt, route.routeJson, airplaneId).run();
      if (plane.reply_to_id) {
        await env.DB.prepare(
          "UPDATE airplanes SET status = 'RESPONDED' WHERE id = ? AND status IN ('DELIVERED','READ')",
        ).bind(plane.reply_to_id).run();
      }
    } else {
      await env.DELIVERY_QUEUE.send({ type: "MATCH_AIRPLANE", airplaneId });
    }
    return json({ ok: true, status: nextStatus });
  }

  const adminReplyReviewMatch = path.match(/^\/v1\/admin\/replies\/([^/]+)$/);
  if (adminReplyReviewMatch && method === "POST") {
    if (!isAdmin) return json({ error: "FORBIDDEN" }, 403);
    const body = await request.json().catch(() => ({})) as Record<string, unknown>;
    if (body.action !== "approve" && body.action !== "reject") return json({ error: "INVALID_ACTION" }, 400);
    const reply = await env.DB.prepare(
      "SELECT id, sender_uid FROM public_replies WHERE id = ? AND moderation_state = 'REVIEW'",
    ).bind(adminReplyReviewMatch[1]).first<{ id: string; sender_uid: string }>();
    if (!reply) return json({ error: "NOT_FOUND" }, 404);
    if (body.action === "reject") {
      await env.DB.prepare("UPDATE public_replies SET moderation_state = 'UNSAFE' WHERE id = ?")
        .bind(reply.id).run();
      return json({ ok: true, moderation: "UNSAFE" });
    }
    const replySender = await requireUser(reply.sender_uid, env);
    if (!replySender || replySender.status !== "ACTIVE" ||
        !["UNDER_18", "ADULT"].includes(replySender.declared_age_band)) {
      return json({ error: "AGE_DECLARATION_REQUIRED" }, 403);
    }
    await env.DB.prepare("UPDATE public_replies SET moderation_state = 'SAFE' WHERE id = ?")
      .bind(reply.id).run();
    return json({ ok: true, moderation: "SAFE" });
  }

  if (method === "GET" && path === "/v1/support/tickets") {
    const rows = await env.DB.prepare(
      "SELECT id, category, subject, details, status, created_at, updated_at FROM support_tickets WHERE uid = ? ORDER BY created_at DESC LIMIT 30",
    ).bind(uid).all();
    return json({ items: rows.results ?? [] });
  }

  if (method === "POST" && path === "/v1/support/tickets") {
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    if (!body) return json({ error: "INVALID_JSON" }, 400);
    const category = text(body.category, 24).toUpperCase();
    const allowedCategories = new Set(["TECHNICAL", "ACCOUNT", "DELIVERY", "SAFETY", "SUGGESTION", "OTHER"]);
    const subject = text(body.subject, 100);
    const details = text(body.details, 1200);
    if (!allowedCategories.has(category)) return json({ error: "INVALID_SUPPORT_CATEGORY" }, 400);
    if (subject.length < 3 || details.length < 10) {
      return json({ error: "SUPPORT_MESSAGE_TOO_SHORT", message: "Indica um assunto e descreve o problema com pelo menos 10 caracteres." }, 400);
    }
    const recent = await env.DB.prepare(
      "SELECT COUNT(*) AS count FROM support_tickets WHERE uid = ? AND created_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 day')",
    ).bind(uid).first<{ count: number }>();
    if (Number(recent?.count ?? 0) >= 5) return json({ error: "SUPPORT_RATE_LIMIT" }, 429);
    const id = uuid();
    await env.DB.batch([
      env.DB.prepare(
        "INSERT INTO support_tickets(id, uid, category, subject, details) VALUES (?, ?, ?, ?, ?)",
      ).bind(id, uid, category, subject, details),
      env.DB.prepare(
        "INSERT INTO audit_events(id, actor_uid, event_type, entity_id, metadata_json) VALUES (?, ?, 'SUPPORT_TICKET_CREATED', ?, ?)",
      ).bind(uuid(), uid, id, JSON.stringify({ category })),
    ]);
    return json({ ok: true, ticket: { id, category, subject, status: "OPEN" } }, 201);
  }

  if (method === "POST" && path === "/v1/users/bootstrap") {
    const user = await bootstrap(uid, env);
    return json({ pilot: user, canSend: !!user && ["UNDER_18", "ADULT"].includes(user.declared_age_band) });
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
    if (["UNDER_18", "ADULT"].includes(user.declared_age_band)) {
      await env.DB.prepare(
        "UPDATE onboarding_first_flights SET state = 'READY_TO_LAUNCH', updated_at = ? WHERE uid = ? AND state = 'WAITING_FOR_AGE_VERIFICATION'",
      ).bind(isoNow(), uid).run();
    }
    const firstFlight = await env.DB.prepare(
      "SELECT state, message_text, plane_model FROM onboarding_first_flights WHERE uid = ?",
    ).bind(uid).first<{ state: string; message_text: string; plane_model: string }>();
    return json({
      pilot: user,
      stats: { sent: stats?.sent ?? 0, received: received?.received ?? 0 },
      firstFlightState: firstFlight?.state ?? null,
      firstFlight: firstFlight ? {
        state: firstFlight.state,
        message: firstFlight.message_text,
        planeModel: firstFlight.plane_model,
      } : null,
    });
  }

  if (method === "GET" && path === "/v1/atlas") {
    const rows = await env.DB.prepare(
      "SELECT status, flight_distance_km, route_json, plane_model FROM airplanes WHERE (sender_uid = ? OR recipient_uid = ?) AND route_json IS NOT NULL ORDER BY created_at DESC LIMIT 500",
    ).bind(uid, uid).all<{
      status: string;
      flight_distance_km: number | null;
      route_json: string | null;
      plane_model: string | null;
    }>();
    const countries = new Set<string>();
    const models: Record<string, number> = { DART: 0, GLIDER: 0, SWALLOW: 0 };
    let totalDistanceKm = 0;
    let completedFlights = 0;
    let activeFlights = 0;
    for (const row of rows.results ?? []) {
      const model = row.plane_model ?? "DART";
      if (model in models) models[model] += 1;
      if (["DELIVERED", "READ", "RESPONDED"].includes(row.status)) completedFlights += 1;
      if (["QUEUED", "FLYING"].includes(row.status)) activeFlights += 1;
      if (row.status !== "REJECTED" && row.status !== "CANCELLED") {
        totalDistanceKm += row.flight_distance_km ?? 0;
      }
      try {
        const route = row.route_json ? JSON.parse(row.route_json) as {
          originCountry?: string; destinationCountry?: string;
        } : null;
        if (route?.originCountry && COUNTRY_CENTROIDS[route.originCountry]) countries.add(route.originCountry);
        if (route?.destinationCountry && COUNTRY_CENTROIDS[route.destinationCountry]) countries.add(route.destinationCountry);
      } catch {
        // Ignore malformed legacy route snapshots; the user's other journeys remain visible.
      }
    }
    const items = [...countries]
      .map((code) => ({ code, name: COUNTRY_CENTROIDS[code].name }))
      .sort((a, b) => a.name.localeCompare(b.name));
    return json({
      countries: items,
      stats: {
        totalFlights: rows.results?.length ?? 0,
        completedFlights,
        activeFlights,
        totalDistanceKm,
        countriesCount: items.length,
        models,
      },
    });
  }

  if (method === "POST" && path === "/v1/onboarding/first-flight") {
    const user = await requireUser(uid, env);
    if (!user || user.profile_completed !== 1 || !user.country_code) {
      return json({ error: "PROFILE_SETUP_REQUIRED" }, 409);
    }
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    if (!body) return json({ error: "INVALID_JSON" }, 400);
    const message = text(body.message, 200);
    const planeModel = text(body.planeModel, 16).toUpperCase() || "DART";
    if (!message || [...message].length > 200) {
      return json({ error: "MESSAGE_LENGTH", message: "Write 1 to 200 characters for your first plane." }, 400);
    }
    if (!["DART", "GLIDER", "SWALLOW"].includes(planeModel)) {
      return json({ error: "INVALID_PLANE_MODEL" }, 400);
    }
    if (!["UNDER_18", "ADULT"].includes(user.declared_age_band)) {
      return json({ error: "AGE_DECLARATION_REQUIRED", message: "Complete your date of birth in the pilot profile first." }, 409);
    }
    const state = "READY_TO_LAUNCH";
    await env.DB.prepare(
      "INSERT INTO onboarding_first_flights(uid, message_text, plane_model, state, updated_at) VALUES (?, ?, ?, ?, ?) ON CONFLICT(uid) DO UPDATE SET message_text = excluded.message_text, plane_model = excluded.plane_model, state = excluded.state, updated_at = excluded.updated_at",
    ).bind(uid, message, planeModel, state, isoNow()).run();
    return json({
      completed: true,
      state,
      privateOnly: false,
      message: "Your first plane is ready for launch using the age group declared in your profile.",
    }, 201);
  }

  if (method === "GET" && path === "/v1/meta/countries") {
    return json({
      items: Object.entries(COUNTRY_CENTROIDS)
        .map(([code, country]) => ({ code, name: country.name }))
        .sort((a, b) => a.name.localeCompare(b.name)),
    });
  }

  if (method === "GET" && path === "/v1/users/handle-availability") {
    const handle = normalizePilotHandle(url.searchParams.get("handle"));
    if (!isValidPilotHandle(handle)) return json({ valid: false, available: false, error: "INVALID_PILOT_HANDLE" });
    const existing = await env.DB.prepare(
      "SELECT uid FROM users WHERE lower(pilot_handle) = ? AND uid <> ? LIMIT 1",
    ).bind(handle, uid).first<{ uid: string }>();
    return json({ valid: true, available: !existing });
  }

  if (method === "POST" && path === "/v1/profile") {
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    if (!body) return json({ error: "INVALID_JSON" }, 400);
    const pilotName = text(body.pilotName, 40);
    const handle = normalizePilotHandle(body.pilotHandle);
    const birthDateText = text(body.birthDate, 10);
    const birthDateMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(birthDateText);
    const countryCode = text(body.countryCode, 2).toUpperCase();
    const language = body.language === "en" ? "en" : "pt";
    if (pilotName.length < 2) return json({ error: "INVALID_PILOT_NAME" }, 400);
    if (!isValidPilotHandle(handle)) return json({ error: "INVALID_PILOT_HANDLE" }, 400);
    if (!birthDateMatch) return json({ error: "INVALID_BIRTH_DATE" }, 400);
    const birthYear = Number(birthDateMatch[1]);
    const birthMonth = Number(birthDateMatch[2]);
    const birthDay = Number(birthDateMatch[3]);
    const birthDate = new Date(Date.UTC(birthYear, birthMonth - 1, birthDay));
    if (
      !Number.isFinite(birthDate.getTime()) ||
      birthDate.getUTCFullYear() !== birthYear ||
      birthDate.getUTCMonth() !== birthMonth - 1 ||
      birthDate.getUTCDate() !== birthDay
    ) return json({ error: "INVALID_BIRTH_DATE" }, 400);
    const today = new Date();
    let declaredAge = today.getUTCFullYear() - birthYear;
    if (
      today.getUTCMonth() < birthMonth - 1 ||
      (today.getUTCMonth() === birthMonth - 1 && today.getUTCDate() < birthDay)
    ) declaredAge -= 1;
    if (declaredAge < 13 || declaredAge > 120) {
      return json({ error: "AGE_NOT_ELIGIBLE", message: "The declared date of birth must indicate an age between 13 and 120." }, 400);
    }
    const declaredAgeBand = declaredAge < 18 ? "UNDER_18" : "ADULT";
    if (!COUNTRY_CENTROIDS[countryCode]) return json({ error: "INVALID_COUNTRY" }, 400);
    try {
      await env.DB.prepare(
        "UPDATE users SET pilot_name = ?, pilot_handle = ?, birth_year = ?, declared_age_band = ?, age_declaration_at = ?, country_code = ?, language = ?, profile_completed = 1, updated_at = ? WHERE uid = ?",
      ).bind(pilotName, handle, birthYear, declaredAgeBand, isoNow(), countryCode, language, isoNow(), uid).run();
      await env.DB.prepare(
        "UPDATE onboarding_first_flights SET state = 'READY_TO_LAUNCH', updated_at = ? WHERE uid = ? AND state = 'WAITING_FOR_AGE_VERIFICATION'",
      ).bind(isoNow(), uid).run();
    } catch (error) {
      if (String(error).toLowerCase().includes("unique")) {
        return json({ error: "PILOT_HANDLE_TAKEN", message: "This pilot name is already in use." }, 409);
      }
      throw error;
    }
    const pilot = await requireUser(uid, env);
    return json({
      pilot,
      canSend: !!pilot && ["UNDER_18", "ADULT"].includes(pilot.declared_age_band),
      ageDeclaration: "SELF_DECLARED",
    });
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
      "SELECT id, audience, status, destination_country, created_at, matched_at, delivered_at, read_at, flight_distance_km, flight_duration_seconds, flight_started_at, estimated_arrival_at FROM airplanes WHERE sender_uid = ? ORDER BY created_at DESC LIMIT 100",
    ).bind(uid).all();
    return json({ items: rows.results ?? [] });
  }

  const flightMatch = path.match(/^\/v1\/airplanes\/([^/]+)\/flight$/);
  if (method === "GET" && flightMatch) {
    const plane = await env.DB.prepare(
      "SELECT id, sender_uid, recipient_uid, status, destination_country, created_at, matched_at, delivered_at, read_at, flight_distance_km, flight_duration_seconds, flight_started_at, estimated_arrival_at, route_json FROM airplanes WHERE id = ? AND (sender_uid = ? OR recipient_uid = ?) LIMIT 1",
    ).bind(flightMatch[1], uid, uid).first<{
      id: string; sender_uid: string; recipient_uid: string | null; status: string;
      destination_country: string | null; created_at: string; matched_at: string | null;
      delivered_at: string | null; read_at: string | null; flight_distance_km: number | null;
      flight_duration_seconds: number | null; flight_started_at: string | null;
      estimated_arrival_at: string | null; route_json: string | null;
    }>();
    if (!plane) return json({ error: "NOT_FOUND" }, 404);
    let route: { points?: Array<{ lat: number; lng: number }>; [key: string]: unknown } | null = null;
    try { route = plane.route_json ? JSON.parse(plane.route_json) : null; } catch { route = null; }
    const progress = flightProgress(plane.flight_started_at, plane.estimated_arrival_at, plane.status);
    let currentPosition: { lat: number; lng: number } | null = null;
    const points = route?.points ?? [];
    if (points.length > 0) {
      const scaled = progress * (points.length - 1);
      const index = Math.min(points.length - 2, Math.floor(scaled));
      const fraction = scaled - index;
      const first = points[index] ?? points[0];
      const second = points[Math.min(points.length - 1, index + 1)] ?? first;
      currentPosition = {
        lat: first.lat + (second.lat - first.lat) * fraction,
        lng: first.lng + (second.lng - first.lng) * fraction,
      };
    }
    return json({
      flight: {
        id: plane.id, status: plane.status,
        searching: plane.status === "QUEUED",
        distanceKm: plane.flight_distance_km,
        durationSeconds: plane.flight_duration_seconds,
        startedAt: plane.flight_started_at,
        estimatedArrivalAt: plane.estimated_arrival_at,
        deliveredAt: plane.delivered_at,
        readAt: plane.read_at,
        progress,
        currentPosition,
        route,
      },
    });
  }

  const heartMatch = path.match(/^\/v1\/airplanes\/([^/]+)\/heart$/);
  if (method === "POST" && heartMatch) {
    const result = await env.DB.prepare(
      "INSERT OR IGNORE INTO airplane_hearts(airplane_id, uid) SELECT id, ? FROM airplanes WHERE id = ? AND recipient_uid = ? AND status IN ('DELIVERED','READ','RESPONDED')",
    ).bind(uid, heartMatch[1], uid).run();
    if ((result.meta?.changes ?? 0) !== 1) {
      const existing = await env.DB.prepare(
        "SELECT 1 AS found FROM airplane_hearts WHERE airplane_id = ? AND uid = ?",
      ).bind(heartMatch[1], uid).first();
      if (!existing) return json({ error: "NOT_FOUND_OR_NOT_RECEIVED" }, 404);
      return json({ ok: true, hearted: true, alreadySent: true });
    }
    return json({ ok: true, hearted: true });
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
    const reason = text(body.reason, 32).toUpperCase() || "OTHER";
    const allowedReasons = new Set([
      "HARASSMENT", "THREATS", "SEXUAL_CONTENT", "GROOMING",
      "SPAM", "PERSONAL_INFO", "IMPERSONATION", "OTHER",
    ]);
    if (!allowedReasons.has(reason)) return json({ error: "INVALID_REPORT_CATEGORY" }, 400);
    const airplaneId = reportMatch[1];
    const existing = await env.DB.prepare(
      "SELECT id FROM reports WHERE reporter_uid = ? AND airplane_id = ? AND status IN ('OPEN','IN_REVIEW') LIMIT 1",
    ).bind(uid, airplaneId).first();
    if (existing) return json({ error: "REPORT_ALREADY_OPEN" }, 409);
    const recent = await env.DB.prepare(
      "SELECT COUNT(*) AS count FROM reports WHERE reporter_uid = ? AND created_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-1 day')",
    ).bind(uid).first<{ count: number }>();
    if (Number(recent?.count ?? 0) >= 20) return json({ error: "REPORT_RATE_LIMIT" }, 429);
    const id = uuid();
    await env.DB.prepare(
      "INSERT INTO reports(id, reporter_uid, airplane_id, reported_uid, reason, details) SELECT ?, ?, a.id, a.sender_uid, ?, ? FROM airplanes a WHERE a.id = ? AND a.sender_uid <> ? AND (a.recipient_uid = ? OR a.audience = 'PUBLIC')",
    ).bind(id, uid, reason, text(body.details, 500) || null, airplaneId, uid, uid).run();
    const created = await env.DB.prepare("SELECT id FROM reports WHERE id = ?").bind(id).first();
    if (!created) return json({ error: "NOT_FOUND" }, 404);
    await env.DB.prepare(
      "INSERT INTO audit_events(id, actor_uid, event_type, entity_id, metadata_json) VALUES (?, ?, 'MESSAGE_REPORTED', ?, ?)",
    ).bind(uuid(), uid, airplaneId, JSON.stringify({ category: reason, reportId: id })).run();
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

  if (method === "POST" && path === "/v1/devices/state") {
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    const token = text(body?.token, 4096);
    if (token.length < 40) return json({ error: "INVALID_DEVICE_TOKEN" }, 400);
    const device = await env.DB.prepare(
      "SELECT 1 AS registered FROM devices WHERE uid = ? AND fcm_token = ? LIMIT 1",
    ).bind(uid, token).first();
    return json({ enabled: Boolean(device) });
  }

  if (method === "POST" && path === "/v1/devices/unregister") {
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    const token = text(body?.token, 4096);
    if (!token) return json({ error: "INVALID_DEVICE_TOKEN" }, 400);
    await env.DB.batch([
      env.DB.prepare("DELETE FROM devices WHERE uid = ? AND fcm_token = ?").bind(uid, token),
      env.DB.prepare(
        "UPDATE users SET push_enabled = CASE WHEN EXISTS (SELECT 1 FROM devices d WHERE d.uid = users.uid) THEN 1 ELSE 0 END, updated_at = ? WHERE uid = ?",
      ).bind(isoNow(), uid),
    ]);
    const remaining = await env.DB.prepare(
      "SELECT COUNT(*) AS count FROM devices WHERE uid = ?",
    ).bind(uid).first<{ count: number }>();
    return json({ ok: true, notificationsEnabled: Number(remaining?.count ?? 0) > 0 });
  }

  if (method === "POST" && path === "/v1/devices/register") {
    const body = await request.json().catch(() => null) as Record<string, unknown> | null;
    const token = text(body?.token, 4096);
    const platform = body?.platform === "ios" || body?.platform === "web" ? body.platform : "android";
    if (token.length < 40) return json({ error: "INVALID_DEVICE_TOKEN" }, 400);
    const id = uuid();
    await env.DB.batch([
      env.DB.prepare(
        "INSERT INTO devices(id, uid, fcm_token, platform) VALUES (?, ?, ?, ?) ON CONFLICT(fcm_token) DO UPDATE SET uid = excluded.uid, platform = excluded.platform, updated_at = ?",
      ).bind(id, uid, token, platform, isoNow()),
      env.DB.prepare("UPDATE users SET push_enabled = 1, updated_at = ? WHERE uid = ?").bind(isoNow(), uid),
    ]);
    return json({ ok: true, notificationsEnabled: true }, 201);
  }

  if (method === "GET" && path === "/v1/open-sky") {
    const country = text(url.searchParams.get("country"), 2).toUpperCase() || null;
    const language = url.searchParams.get("language") === "en" ? "en" : url.searchParams.get("language") === "pt" ? "pt" : null;
    const rows = await env.DB.prepare(
      `SELECT a.id, a.message_text, a.message_language, a.mood, a.sender_country_code, a.created_at, p.likes_count,
              CASE WHEN a.sender_uid = ? THEN 1 ELSE 0 END AS is_own,
              (SELECT COUNT(*) FROM public_replies r WHERE r.airplane_id = a.id AND r.moderation_state = 'SAFE') AS replies_count
       FROM public_sky p JOIN airplanes a ON a.id = p.airplane_id
       WHERE a.audience = 'PUBLIC' AND a.moderation_state = 'SAFE' AND a.status = 'DELIVERED'
         AND (? IS NULL OR a.sender_country_code = ?)
         AND (? IS NULL OR a.message_language = ?)
       ORDER BY a.created_at DESC LIMIT 50`,
    ).bind(uid, country, country, language, language).all();
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
    const { user, response } = await ensurePilotReady(uid, env);
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
    if (moderation.state === "UNSAFE") return json({ error: "MESSAGE_NOT_ALLOWED" }, 422);
    const id = uuid();
    const moderationState = moderation.state === "SAFE" ? "SAFE" : "REVIEW";
    try {
      await env.DB.prepare("INSERT INTO public_replies(id, airplane_id, sender_uid, message_text, moderation_state) VALUES (?, ?, ?, ?, ?)")
        .bind(id, publicRepliesMatch[1], uid, message, moderationState).run();
    } catch (error) {
      const reason = String(error);
      if (reason.includes("PAPER_PLANE_RATE_LIMIT")) return json({ error: "RATE_LIMIT_EXCEEDED" }, 429);
      if (reason.includes("PUBLIC_REPLY_LIMIT_REACHED")) return json({ error: "REPLY_LIMIT_REACHED" }, 429);
      throw error;
    }
    return moderationState === "SAFE"
      ? json({ id, status: "PUBLISHED" }, 201)
      : json({ id, status: "HELD_REVIEW" }, 202);
  }

  const translationMatch = path.match(/^\/v1\/airplanes\/([^/]+)\/translation$/);
  if (method === "POST" && translationMatch) {
    const body = await request.json().catch(() => ({})) as Record<string, unknown>;
    const target = body.language === "en" ? "en" : "pt";
    const plane = await env.DB.prepare(
      "SELECT message_text, sender_uid, recipient_uid, audience, moderation_state FROM airplanes WHERE id = ?",
    ).bind(translationMatch[1]).first<{ message_text: string; sender_uid: string; recipient_uid: string | null; audience: string; moderation_state: string }>();
    if (!plane || (plane.sender_uid !== uid && plane.recipient_uid !== uid && plane.audience !== "PUBLIC") || plane.moderation_state !== "SAFE") return json({ error: "NOT_FOUND" }, 404);
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
        // Delivery is finalized by cron after the stored arrival timestamp.
        message.ack();
      } catch {
        message.retry({ delaySeconds: 60 });
      }
    }
  },

  async scheduled(_controller: ScheduledController, env: Env, _ctx: ExecutionContext): Promise<void> {
    // Keep searching until an eligible pilot is found. There is no fake delivery timer.
    const queued = await env.DB.prepare(
      "SELECT id FROM airplanes WHERE status = 'QUEUED' AND moderation_state = 'SAFE' ORDER BY created_at ASC LIMIT 40",
    ).all<{ id: string }>();
    for (const plane of queued.results ?? []) {
      await matchAirplane(plane.id, env);
    }

    // Finish a flight only after its persisted arrival time.
    const arrived = await env.DB.prepare(
      "SELECT id FROM airplanes WHERE status = 'FLYING' AND recipient_uid IS NOT NULL AND estimated_arrival_at IS NOT NULL AND estimated_arrival_at <= ? ORDER BY estimated_arrival_at ASC LIMIT 40",
    ).bind(isoNow()).all<{ id: string }>();
    for (const plane of arrived.results ?? []) {
      await deliverAirplane(plane.id, env);
    }

    // Expire unread mail after 24 hours and opened mail 48 hours after it was opened.
    await env.DB.prepare(
      "UPDATE airplanes SET status = 'EXPIRED' WHERE status IN ('DELIVERED','READ') AND expires_at IS NOT NULL AND expires_at <= ?",
    ).bind(isoNow()).run();
  },
};
