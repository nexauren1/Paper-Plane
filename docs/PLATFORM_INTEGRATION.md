# Paper Plane — Platform integration

This branch prepares the production architecture without committing private credentials.

## Responsibility split

- Flutter / Dart: mobile interface and client-side animations.
- Firebase Authentication: Email/Password or Google account identity; the Worker verifies every Firebase ID token and uses its immutable UID as the D1 `users.uid` primary key. No separate `identity` table is required.
- Firebase Cloud Messaging: device push notifications. FCM is opt-in and notification text deliberately does not include the letter itself.
- Cloudflare Worker: authenticated API, business rules, matching, safety gates, delivery state, and AI orchestration.
- Cloudflare D1: primary relational database. Message data is not duplicated into Firestore.
- Cloudflare Queues: asynchronous matching and delivery notifications.
- Workers AI: Meta M2M100 1.2B provides multilingual airplane translation on inbox open and per-message translation inside Chat/Chama. Sending and recipient matching never wait for translation. There is no AI chatbot or AI compose button.
- Cloudflare Pages: public website / help / privacy pages. The Android app calls the Worker API, not Pages Functions.

## What is implemented in this branch

### Firebase client
- Firebase is initialized from build-time --dart-define values.
- Firebase Authentication creates a stable UID for each account. The app bootstraps the matching D1 pilot row after sign-in; the Worker rejects API calls whose Firebase token cannot be verified.
- The Firebase ID token is attached to Worker API requests.
- A notification registration service requests permission only when explicitly called from Settings.
- The app composer calls the Worker when both Firebase and the API URL are configured; otherwise it clearly stays in preview/demo mode.

### Worker API and D1
- Firebase RS256 ID-token signature, issuer, audience, expiry, and subject are verified on the Worker.
- Pilot bootstrap and profile, inbox, sent-plane, Open Sky, reporting, blocking, public likes/replies, airplane translation, chat translation, and device registration endpoints are implemented. The core Flutter screens request live API data; they must still be integration-tested against production resources.
- Original planes have unlimited daily sending, a rolling hourly anti-spam safeguard, and a 200-character limit.
- Random planes are matched immediately when an eligible recipient exists, then retried by the queue and scheduled matcher when nobody is available; they are never falsely marked delivered.
- Matching only considers active users in the same self-declared age group. Blocks apply in both directions; this is cohort separation, not proof of age.
- Unread delivered letters expire after 24 hours. Once opened, the retention window changes to 48 hours.
- A reply must be allowed by the original sender.
- Open Sky supports up to five public replies.
- Reports, blocks, and administrative actions are stored in D1. Admin-only endpoints can list open reports, dismiss/action reports, and suspend accounts. Admin access uses the Worker secret ADMIN_UIDS.
- Moderation review endpoints are restricted to Firebase UIDs listed in the Worker secret ADMIN_UIDS.

### Message safety and AI translation
- The current Worker moderation function returns SAFE without running a content classifier. Automated content moderation and an operational human-review process are not implemented yet; do not present them as active protections.
- Reporting, blocking, account actions, same-age-cohort matching, and rolling hourly anti-spam controls are implemented. These controls do not replace content moderation or guarantee that harmful messages will be detected.
- Workers AI uses `@cf/meta/m2m100-1.2b` for translation only. Incoming airplanes are translated when opened if the recipient's preferred language differs from the source. Chat and Chama bubbles can be translated on demand; the original text remains available and translated results are cached in D1. Translation failure never blocks sending or delivery.
- Automated screening now has a server-side classifier, and the Admin app exposes held planes, held public replies and user reports for operator review. A staffed human-review schedule, escalation policy, account deletion/export tests, retention procedures and launch-country legal review remain pre-release requirements.

## Self-declared age groups and child safety

The profile form asks users to declare their full date of birth. The Worker validates the calendar date, calculates the age using server time, and assigns one of two cohorts: `UNDER_18` or `ADULT`. The app does not send users to a third-party identity or document-verification provider.

For data minimization, the Worker does not retain the full date of birth. D1 keeps the birth year, the derived declared age group, and the time of declaration. Users must be at least 13 according to the date they enter. A declared date is not proof of age or identity and can be inaccurate or deliberately false.

Random and direct matching only pair users in the same declared age group. The server also enforces account status, profile completion, consent, blocks, and open reports. This separation is a basic risk-reduction measure, not a guarantee that a user is who they say they are or that contact is safe.

Moderation, reporting, blocking, rate limits, human review, transparent community rules, and careful handling of reports remain essential. Do not use AI to infer a person's age from appearance, voice, writing style, or other speculative signals. Any account-risk signals should be treated as review cues, not proof of lying.

## Firebase setup

1. Open the existing Firebase project.
2. In Authentication → Sign-in method, enable Anonymous, Email/Password, and Google.
3. Enable Firebase Cloud Messaging and Google Analytics for the Android app.
4. The Android app package is com.nexauren.paper_plane. The supplied client configuration is stored at firebase/google-services.json and copied into android/app/google-services.json by the Android build workflow.
5. The workflow reads the Firebase API key, Android App ID, project number, Project ID, and Web OAuth client ID from that file. It configures the Google Services Gradle plugin and passes the values into the Flutter build. No manual Dart defines are needed for GitHub Actions.
6. Google sign-in uses the Web OAuth client (oauth_client client_type 3) from the Firebase file. Add the SHA-1 and SHA-256 fingerprints for the certificate used to sign the APK in Firebase Project settings → Your apps → Android app, then download a fresh google-services.json and replace firebase/google-services.json. The current uploaded file has the Web OAuth client, but no Android OAuth client entry yet; Google sign-in can fail until the signing fingerprint is registered.
   - Permanent upload-key SHA-1: `F4:5F:3C:66:21:1A:38:23:59:34:DF:C8:07:16:A2:E1:2D:4B:3A:7F`.
   - Permanent upload-key SHA-256: `6E:9B:24:0E:19:3B:53:E1:92:FB:3C:11:D4:06:EC:E4:77:EC:E8:CA:50:15:93:07:21:05:A6:39:74:79:10:6B`.
   - These fingerprints belong to the permanent `paper-plane-upload` keystore used by the release workflow. Do not replace the keystore after publishing this APK package.
7. Analytics collection is enabled after Firebase initializes. The app records app_open, sign_up, login, and logout events; it does not send message text or passwords to Analytics.
8. Notification registration remains an explicit opt-in in Settings. The Firebase service registers the FCM token with the Worker only after the user enables notifications.

The client configuration contains identifiers and an API key intended for use by the mobile app; it is not a service-account credential. Never commit a Firebase service-account private key, Cloudflare API token, or FCM service-account JSON.
## Cloudflare setup

### Cloudflare Workers Builds settings

For the Git-connected Worker build in Cloudflare, set the repository root directory to `cloudflare/worker`. Keep the build command empty for this TypeScript Worker and set the deploy command to `npm run deploy` (the script invokes the repository-pinned Wrangler dependency). The Wrangler configuration is `wrangler.jsonc` in that directory and its entry point is `src/index.ts`. A build launched before this root-directory setting is saved may run from the repository root and fail to locate the Worker configuration; rerun the build after saving the setting.

From cloudflare/worker:
~~~~bash
npm install
npx wrangler login
# D1 já criado pelo proprietário do projeto:
# database_name = paper_plane_db
# database_id = fcca4c13-7b08-466d-9fdc-0e5dfac54ca9
# NÃO executar "wrangler d1 create" novamente.
npx wrangler queues create paper-plane-delivery
npx wrangler queues create paper-plane-delivery-dlq
~~~~

The supplied D1 database ID and name are already recorded in wrangler.jsonc. Do not create a second D1 database. Replace FIREBASE_PROJECT_ID with the Firebase project's exact Project ID and APP_ORIGINS with the exact Pages website origin(s), comma-separated. The Worker name is set to paper-plane to match the supplied workers.dev address.

Then apply the schema and deploy:
~~~~bash
npm run db:remote
npm run typecheck
npx wrangler secret put FCM_SERVICE_ACCOUNT_JSON
npx wrangler secret put ADMIN_UIDS
npm run deploy
~~~~

For FCM_SERVICE_ACCOUNT_JSON, paste the JSON of a dedicated Google service account with the minimum permissions required to send Firebase Cloud Messaging messages. Do not commit that JSON, put it in Dart defines, or send it in chat. If this secret is absent, D1 delivery still works but push notifications are skipped.

For ADMIN_UIDS, enter a comma-separated list of trusted Firebase UIDs that are allowed to review held messages. Keep this secret limited to the smallest possible group. The moderation review endpoints are not a substitute for a staffed safety process.

The Worker AI binding is declared in wrangler.jsonc. Confirm Workers AI is enabled for the Cloudflare account. The Queue names must exist before deploy. The scheduled trigger revisits queued planes every five minutes and expires letters according to their stored expiry time.

## GitHub deployment option

A manual-only deployment workflow is included at .github/workflows/deploy-worker.yml. Before using it, add these repository Actions secrets:

- CLOUDFLARE_API_TOKEN — a scoped token that can deploy Workers and apply D1 migrations.
- CLOUDFLARE_ACCOUNT_ID — the Cloudflare account ID.

The D1 database and Queue resources must already exist, and wrangler.jsonc must contain the real D1 database ID and Firebase Project ID. The Worker secrets FCM_SERVICE_ACCOUNT_JSON and ADMIN_UIDS are configured in Cloudflare, not GitHub. Then run the "Deploy Paper Plane Worker" workflow manually from the platform-integration branch.

The automatic Cloudflare CI checks also validate both SQL migrations in an in-memory SQLite database and typecheck the Worker code. They do not deploy anything.

## Permanent Android release signing

The Android workflow supports four repository Actions secrets:
- `ANDROID_KEYSTORE_BASE64`: Base64 contents of the permanent upload keystore.
- `ANDROID_KEYSTORE_PASSWORD`: keystore password.
- `ANDROID_KEY_ALIAS`: `paper-plane-upload`.
- `ANDROID_KEY_PASSWORD`: private-key password.

When all four secrets exist, `tool/prepare_android_signing.py` decodes the keystore, creates the temporary Gradle signing properties, and configures the release build to use that key. The keystore and passwords must never be committed to the repository. Keep a secure backup: replacing or losing this signing key prevents normal in-place updates for APK distributors that require the same signing certificate.

The actual secret values are supplied privately to the repository owner in the generated signing-secrets file and are not stored in this repository. Until all four secrets have been added to GitHub Actions, CI warns and continues with the default Flutter signing configuration; Google sign-in is not expected to work in that unsigned/debug-signed APK.

## Flutter build

GitHub Actions generates the Android platform, copies firebase/google-services.json into android/app, configures the Google Services Gradle plugin, extracts the public Firebase client values, runs the widget tests, and builds the release APK. The build also sets PAPER_PLANE_API_BASE_URL to the deployed Worker endpoint.

For a local build, use the same Firebase values from firebase/google-services.json as Dart defines: FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID, FIREBASE_PROJECT_ID, and GOOGLE_SERVER_CLIENT_ID. The Android Google Services Gradle plugin and google-services.json must also be present under android/app.

## Pages

Pages remains the public website. Use a Worker custom domain such as api.yourdomain.example for the API, and set that exact site origin in APP_ORIGINS. Do not point the mobile app at the Pages website URL unless Pages is deliberately configured to proxy the Worker API.

## Known work still required before public release

- Add the signing certificate SHA-1 and SHA-256 fingerprints to Firebase and refresh firebase/google-services.json before validating Google sign-in on the signed release APK.
- Create the D1 database and Queue resources in the correct Cloudflare account.
- Build the human moderation dashboard/workflow on top of the admin endpoints and define response coverage and escalation procedures.
- Verify local laws and privacy requirements for every launch country, and publish clear notices for self-declared age information and user safety.
- Connect live API data to every visual screen; the composer, auth, notification registration, and API clients are prepared, but inbox, Open Sky, profile, collection, and some other visual screens still show illustrative content.
- Test FCM delivery on a real Android device and configure notification channels.
- Add integration tests using Firebase Auth and Cloudflare staging resources before production.
