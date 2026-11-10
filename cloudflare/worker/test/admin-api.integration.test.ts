import { beforeAll, afterAll, describe, expect, it, vi } from "vitest";
import { env, exports as workerExports } from "cloudflare:workers";
import { applyD1Migrations } from "cloudflare:test";
import { exportJWK, generateKeyPair, SignJWT } from "jose";

const PROJECT_ID = "paper-plane-test-project";
const ADMIN_UID = "test-admin";
const JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

type TestBindings = {
  DB: D1Database;
  TEST_MIGRATIONS: unknown[];
};

const testEnv = env as unknown as TestBindings;
const DB = testEnv.DB;

let privateKey: CryptoKey;
let publicJwk: Record<string, unknown>;
let originalFetch: typeof fetch;
const sentFcmMessages: Array<Record<string, any>> = [];

async function createToken(uid: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({ auth_time: now })
    .setProtectedHeader({ alg: "RS256", kid: "paper-plane-local-test-key" })
    .setIssuer(`https://securetoken.google.com/${PROJECT_ID}`)
    .setAudience(PROJECT_ID)
    .setSubject(uid)
    .setIssuedAt(now)
    .setExpirationTime(now + 300)
    .sign(privateKey);
}

async function api(
  uid: string | null,
  method: string,
  path: string,
  body?: Record<string, unknown>,
): Promise<{ status: number; data: Record<string, any> }> {
  const headers = new Headers({ "Content-Type": "application/json" });
  if (uid) headers.set("Authorization", `Bearer ${await createToken(uid)}`);
  const response = await workerExports.default.fetch(
    new Request(`https://paper-plane.test${path}`, {
      method,
      headers,
      ...(body ? { body: JSON.stringify(body) } : {}),
    }),
  );
  const data = await response.json() as Record<string, any>;
  return { status: response.status, data };
}

async function seedUser(uid: string, code: string, name: string): Promise<void> {
  await DB.prepare(
    "INSERT INTO users(uid, pilot_code, pilot_name) VALUES (?, ?, ?)",
  ).bind(uid, code, name).run();
  await DB.prepare(
    "UPDATE users SET declared_age_band = 'ADULT', age_declaration_at = ?, birth_year = 1995, country_code = 'MZ', country_visible = 1, profile_completed = 1, status = 'ACTIVE', accept_random_mail = 1, push_enabled = 1 WHERE uid = ?",
  ).bind(new Date().toISOString(), uid).run();
}

async function seedPlane(
  id: string,
  senderUid: string,
  audience: "PUBLIC" | "RANDOM" = "PUBLIC",
  status: "HELD_REVIEW" | "DELIVERED" = "HELD_REVIEW",
  moderationState: "REVIEW" | "SAFE" = "REVIEW",
): Promise<void> {
  await DB.prepare(
    `INSERT INTO airplanes(
       id, sender_uid, audience, message_text, message_language,
       allow_reply, status, moderation_state, content_hash
     ) VALUES (?, ?, ?, ?, 'pt', 1, ?, ?, ?)`,
  ).bind(id, senderUid, audience, "Mensagem de teste", status, moderationState, `hash-${id}`).run();
}

describe("Paper Plane Admin API integration", () => {
  beforeAll(async () => {
    await applyD1Migrations(DB, testEnv.TEST_MIGRATIONS as any);

    const keyPair = await generateKeyPair("RS256");
    privateKey = keyPair.privateKey;
    publicJwk = {
      ...(await exportJWK(keyPair.publicKey)),
      kid: "paper-plane-local-test-key",
      alg: "RS256",
      use: "sig",
    };

    // The Worker still executes its real Firebase JWT verification. Only the
    // public JWKS network response is replaced with an ephemeral test key.
    originalFetch = globalThis.fetch.bind(globalThis);
    vi.stubGlobal("fetch", async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = input instanceof Request
        ? input.url
        : input instanceof URL
          ? input.toString()
          : String(input);
      if (url === JWKS_URL) {
        return new Response(JSON.stringify({ keys: [publicJwk] }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      if (url === "https://oauth2.googleapis.com/token") {
        return new Response(JSON.stringify({ access_token: "test-fcm-access-token" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      if (url.startsWith("https://fcm.googleapis.com/v1/projects/")) {
        const requestBody = typeof init?.body === "string" ? JSON.parse(init.body) : {};
        sentFcmMessages.push(requestBody.message ?? {});
        return new Response(JSON.stringify({ name: "projects/paper-plane-test-project/messages/test-message" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      return originalFetch(input, init);
    });

    await seedUser(ADMIN_UID, "CODE-ADMIN-TEST", "Admin Test");
    await seedUser("pilot-test", "CODE-PILOT-TEST", "Pilot Test");
    await seedUser("target-test", "CODE-TARGET-TEST", "Target Test");
    await seedUser("reported-test", "CODE-REPORTED-TEST", "Reported Test");

    await DB.prepare(
      "INSERT INTO devices(id, uid, fcm_token) VALUES (?, ?, ?)",
    ).bind("device-target", "target-test", "test-fcm-token-target").run();
    await DB.prepare(
      "INSERT INTO devices(id, uid, fcm_token) VALUES (?, ?, ?)",
    ).bind("device-admin", ADMIN_UID, "test-fcm-token-admin").run();
    await DB.prepare(
      "INSERT INTO devices(id, uid, fcm_token) VALUES (?, ?, ?)",
    ).bind("device-pilot", "pilot-test", "test-fcm-token-pilot").run();
    await DB.prepare(
      "INSERT INTO devices(id, uid, fcm_token) VALUES (?, ?, ?)",
    ).bind("device-reported", "reported-test", "test-fcm-token-reported").run();

    await DB.prepare(
      "INSERT INTO blocks(blocker_uid, blocked_uid) VALUES (?, ?)",
    ).bind("pilot-test", "target-test").run();

    await seedPlane("report-plane", "pilot-test", "PUBLIC", "DELIVERED", "SAFE");
    await DB.prepare(
      "INSERT INTO public_sky(airplane_id) VALUES (?)",
    ).bind("report-plane").run();

    await DB.prepare(
      "INSERT INTO reports(id, reporter_uid, airplane_id, reported_uid, reason, details) VALUES (?, ?, ?, ?, ?, ?)",
    ).bind("report-dismiss", "pilot-test", "report-plane", "target-test", "SPAM", "Relatório para encerrar no teste.").run();
    await DB.prepare(
      "INSERT INTO reports(id, reporter_uid, airplane_id, reported_uid, reason, details) VALUES (?, ?, ?, ?, ?, ?)",
    ).bind("report-suspend", "pilot-test", "report-plane", "reported-test", "HARASSMENT", "Relatório para testar suspensão.").run();

    await DB.prepare(
      "INSERT INTO support_tickets(id, uid, category, subject, details) VALUES (?, ?, ?, ?, ?)",
    ).bind("support-test", "pilot-test", "TECHNICAL", "Falha no teste", "Pedido de suporte de teste com detalhes suficientes.").run();

    await seedPlane("review-public", "pilot-test", "PUBLIC", "HELD_REVIEW", "REVIEW");
    await seedPlane("review-reject", "pilot-test", "PUBLIC", "HELD_REVIEW", "REVIEW");
    await DB.prepare(
      "INSERT INTO public_replies(id, airplane_id, sender_uid, message_text, moderation_state) VALUES (?, ?, ?, ?, ?)",
    ).bind("reply-review", "report-plane", "pilot-test", "Resposta pendente para revisão.", "REVIEW").run();

    await DB.prepare(
      "INSERT INTO admin_notifications(id, actor_uid, target_type, recipient_uid, title, body, device_count, sent_count, failed_count) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
    ).bind("notification-history-test", ADMIN_UID, "USER", "target-test", "Teste", "Histórico de teste", 1, 1, 0).run();
  }, 30_000);

  afterAll(() => {
    vi.unstubAllGlobals();
  });

  it("validates authentication and executes every Admin operation against local D1", async () => {
    const unauthenticated = await api(null, "GET", "/v1/admin/dashboard");
    expect(unauthenticated.status).toBe(401);

    const nonAdmin = await api("pilot-test", "GET", "/v1/admin/dashboard");
    expect(nonAdmin.status).toBe(403);

    const dashboard = await api(ADMIN_UID, "GET", "/v1/admin/dashboard");
    expect(dashboard.status).toBe(200);
    expect(Number(dashboard.data.users.total)).toBeGreaterThanOrEqual(4);
    expect(Number(dashboard.data.pendingReview.total)).toBe(3);

    const users = await api(ADMIN_UID, "GET", "/v1/admin/users?q=target");
    expect(users.status).toBe(200);
    expect(users.data.items.some((user: any) => user.uid === "target-test")).toBe(true);

    const userDetail = await api(ADMIN_UID, "GET", "/v1/admin/users/target-test");
    expect(userDetail.status).toBe(200);
    expect(userDetail.data.user.uid).toBe("target-test");
    expect(Number(userDetail.data.deviceCount.total)).toBe(1);

    const cannotSuspendSelf = await api(ADMIN_UID, "POST", `/v1/admin/users/${ADMIN_UID}`, { action: "suspend" });
    expect(cannotSuspendSelf.status).toBe(409);

    const suspended = await api(ADMIN_UID, "POST", "/v1/admin/users/target-test", { action: "suspend" });
    expect(suspended.status).toBe(200);
    expect(suspended.data.status).toBe("SUSPENDED");
    const deletedDevice = await DB.prepare(
      "SELECT COUNT(*) AS total FROM devices WHERE uid = ?",
    ).bind("target-test").first<{ total: number }>();
    expect(Number(deletedDevice?.total ?? 0)).toBe(0);

    const activated = await api(ADMIN_UID, "POST", "/v1/admin/users/target-test", { action: "activate" });
    expect(activated.status).toBe(200);
    expect(activated.data.status).toBe("ACTIVE");
    expect((await api(ADMIN_UID, "POST", "/v1/admin/users/target-test", { action: "disable_random" })).status).toBe(200);
    expect((await api(ADMIN_UID, "POST", "/v1/admin/users/target-test", { action: "enable_random" })).status).toBe(200);

    const blocks = await api(ADMIN_UID, "GET", "/v1/admin/blocks");
    expect(blocks.status).toBe(200);
    expect(blocks.data.items).toHaveLength(1);
    const unblocked = await api(ADMIN_UID, "POST", "/v1/admin/blocks/pilot-test/target-test");
    expect(unblocked.status).toBe(200);
    const remainingBlocks = await DB.prepare("SELECT COUNT(*) AS total FROM blocks").first<{ total: number }>();
    expect(Number(remainingBlocks?.total ?? 0)).toBe(0);

    const reports = await api(ADMIN_UID, "GET", "/v1/admin/reports");
    expect(reports.status).toBe(200);
    expect(reports.data.items).toHaveLength(2);
    expect((await api(ADMIN_UID, "POST", "/v1/admin/reports/report-dismiss", { action: "dismiss" })).status).toBe(200);
    const reportSuspension = await api(ADMIN_UID, "POST", "/v1/admin/reports/report-suspend", { action: "suspend_user" });
    expect(reportSuspension.status).toBe(200);
    expect(reportSuspension.data.status).toBe("SUSPENDED");
    const reportedUser = await DB.prepare("SELECT status FROM users WHERE uid = ?").bind("reported-test").first<{ status: string }>();
    expect(reportedUser?.status).toBe("SUSPENDED");
    const reportedDevices = await DB.prepare("SELECT COUNT(*) AS total FROM devices WHERE uid = ?").bind("reported-test").first<{ total: number }>();
    expect(Number(reportedDevices?.total ?? 0)).toBe(0);

    const review = await api(ADMIN_UID, "GET", "/v1/admin/review");
    expect(review.status).toBe(200);
    expect(review.data.items).toHaveLength(2);
    expect(review.data.replies).toHaveLength(1);

    const approved = await api(ADMIN_UID, "POST", "/v1/admin/review/review-public", { action: "approve" });
    expect(approved.status).toBe(200);
    expect(approved.data.status).toBe("DELIVERED");
    const publicEntry = await DB.prepare("SELECT 1 AS found FROM public_sky WHERE airplane_id = ?").bind("review-public").first();
    expect(publicEntry).not.toBeNull();

    const rejected = await api(ADMIN_UID, "POST", "/v1/admin/review/review-reject", { action: "reject" });
    expect(rejected.status).toBe(200);
    const rejectedPlane = await DB.prepare("SELECT status FROM airplanes WHERE id = ?").bind("review-reject").first<{ status: string }>();
    expect(rejectedPlane?.status).toBe("REJECTED");

    const rejectedReply = await api(ADMIN_UID, "POST", "/v1/admin/replies/reply-review", { action: "reject" });
    expect(rejectedReply.status).toBe(200);
    const replyState = await DB.prepare("SELECT moderation_state FROM public_replies WHERE id = ?").bind("reply-review").first<{ moderation_state: string }>();
    expect(replyState?.moderation_state).toBe("UNSAFE");

    const support = await api(ADMIN_UID, "GET", "/v1/admin/support");
    expect(support.status).toBe(200);
    expect(support.data.items.some((ticket: any) => ticket.id === "support-test")).toBe(true);
    const supportUpdated = await api(ADMIN_UID, "POST", "/v1/admin/support/support-test", { action: "in_review" });
    expect(supportUpdated.status).toBe(200);
    expect(supportUpdated.data.status).toBe("IN_REVIEW");

    const notifications = await api(ADMIN_UID, "GET", "/v1/admin/notifications");
    expect(notifications.status).toBe(200);
    expect(notifications.data.items.some((item: any) => item.id === "notification-history-test")).toBe(true);
    // OAuth and FCM endpoints are mocked. The test exercises the complete
    // signed-service-account and announcement-dispatch logic without sending
    // messages to real devices or requiring production credentials.
    const targetedPush = await api(ADMIN_UID, "POST", "/v1/admin/notifications", {
      target: "USER",
      targetUid: "pilot-test",
      title: "Aviso individual de teste",
      body: "Aviso dirigido apenas ao copiloto de teste.",
    });
    expect(targetedPush.status).toBe(201);
    expect(targetedPush.data.deviceCount).toBe(1);
    expect(targetedPush.data.sentCount).toBe(1);
    expect(targetedPush.data.failedCount).toBe(0);
    const targetedMessage = sentFcmMessages[sentFcmMessages.length - 1];
    expect(targetedMessage.token).toBe("test-fcm-token-pilot");
    expect(targetedMessage.topic).toBeUndefined();

    const beforeGlobalPush = sentFcmMessages.length;
    const globalPush = await api(ADMIN_UID, "POST", "/v1/admin/notifications", {
      target: "ALL",
      title: "Aviso global de teste",
      body: "Aviso global apenas no ambiente isolado.",
    });
    expect(globalPush.status).toBe(201);
    expect(globalPush.data.deviceCount).toBe(2);
    expect(globalPush.data.sentCount).toBe(2);
    expect(globalPush.data.failedCount).toBe(0);
    const globalMessages = sentFcmMessages.slice(beforeGlobalPush);
    expect(globalMessages.map((message) => message.token).sort()).toEqual([
      "test-fcm-token-admin",
      "test-fcm-token-pilot",
    ]);
    expect(globalMessages.every((message) => message.topic === undefined)).toBe(true);
    expect(globalMessages.every((message) => message.notification?.title === "Aviso global de teste")).toBe(true);

    const noDevicePush = await api(ADMIN_UID, "POST", "/v1/admin/notifications", {
      target: "USER",
      targetUid: "target-test",
      title: "Aviso sem dispositivo",
      body: "Este utilizador não tem token registado no teste.",
    });
    expect(noDevicePush.status).toBe(409);
    expect(noDevicePush.data.error).toBe("NO_REGISTERED_DEVICE");

    const notificationHistory = await DB.prepare(
      "SELECT target_type, recipient_uid, sent_count, failed_count FROM admin_notifications WHERE id IN (?, ?) ORDER BY target_type",
    ).bind(targetedPush.data.id, globalPush.data.id).all<{
      target_type: string; recipient_uid: string | null; sent_count: number; failed_count: number;
    }>();
    expect(notificationHistory.results?.length).toBe(2);
    expect(notificationHistory.results?.every((item) => item.sent_count === 1 && item.failed_count === 0)).toBe(true);

    const auditCount = await DB.prepare(
      "SELECT COUNT(*) AS total FROM audit_events WHERE actor_uid = ?",
    ).bind(ADMIN_UID).first<{ total: number }>();
    expect(Number(auditCount?.total ?? 0)).toBeGreaterThanOrEqual(4);

    const tables = await DB.prepare(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('admin_notifications', 'deleted_accounts') ORDER BY name",
    ).all<{ name: string }>();
    expect((tables.results ?? []).map((table) => table.name)).toEqual(["admin_notifications", "deleted_accounts"]);
  });
});
