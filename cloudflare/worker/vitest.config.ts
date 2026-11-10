import path from "node:path";
import { fileURLToPath } from "node:url";
import { generateKeyPairSync } from "node:crypto";
import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

const workerDirectory = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [
    cloudflareTest(async () => {
      const migrations = await readD1Migrations(
        path.join(workerDirectory, "migrations"),
      );
      // Generate a disposable test-only service account key. The token and FCM
      // endpoints are mocked by the integration test; no real Firebase is called.
      const { privateKey } = generateKeyPairSync("rsa", {
        modulusLength: 2048,
        privateKeyEncoding: { format: "pem", type: "pkcs8" },
        publicKeyEncoding: { format: "pem", type: "spki" },
      });
      const testServiceAccount = JSON.stringify({
        client_email: "paper-plane-test@paper-plane-test-project.iam.gserviceaccount.com",
        private_key: privateKey,
        project_id: "paper-plane-test-project",
      });

      return {
        wrangler: {
          configPath: path.join(workerDirectory, "wrangler.test.jsonc"),
        },
        miniflare: {
          // Test-only bindings: D1 is local and FCM endpoints are intercepted.
          bindings: {
            TEST_MIGRATIONS: migrations,
            FCM_SERVICE_ACCOUNT_JSON: testServiceAccount,
          },
        },
      };
    }),
  ],
  test: {
    include: ["test/**/*.integration.test.ts"],
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 30_000,
  },
});
