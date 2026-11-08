# Paper Plane — Platform integration

This branch prepares the production architecture without committing private credentials.

## Responsibility split

- Flutter / Dart: mobile interface and client-side animations.
- Firebase Authentication: anonymous Firebase identity for a pilot; the Worker verifies each Firebase ID token.
- Firebase Cloud Messaging: device push notifications. FCM is opt-in and notification text deliberately does not include the letter itself.
- Cloudflare Worker: authenticated API, business rules, matching, safety gates, delivery state, and AI orchestration.
- Cloudflare D1: primary relational database. Message data is not duplicated into Firestore.
- Cloudflare Queues: asynchronous matching and delivery notifications.
- Workers AI: internal safety classification, triage, message metadata classification, and requested translation. There is no AI chatbot or AI compose button.
- Cloudflare Pages: public website / help / privacy pages. The Android app calls the Worker API, not Pages Functions.

## What is implemented in this branch

### Firebase client
- Firebase is initialized from build-time --dart-define values.
- Firebase Anonymous Auth creates a stable pilot UID.
- The Firebase ID token is attached to Worker API requests.
- A notification registration service requests permission only when explicitly called from Settings.
- The app composer calls the Worker when both Firebase and the API URL are configured; otherwise it clearly stays in preview/demo mode.

### Worker API and D1
- Firebase RS256 ID-token signature, issuer, audience, expiry, and subject are verified on the Worker.
- Pilot bootstrap and profile, inbox, sent-plane, Open Sky, reporting, blocking, public likes/replies, translation, and device registration endpoints are scaffolded.
- Original planes have a one-per-UTC-day limit and a 200-character limit.
- Random planes remain queued when there is no eligible recipient; they are not falsely marked delivered.
- Matching only considers active users whose age group has been verified by a trusted process and is identical to the sender's group. Blocks apply in both directions.
- Unread delivered letters expire after 24 hours. Once opened, the retention window changes to 48 hours.
- A reply must be allowed by the original sender.
- Open Sky supports up to five public replies.
- Reports and administrative review records are stored in D1. Admin-only endpoints can list held AI-review messages and open reports, dismiss/action reports, approve/reject held planes, or suspend an account. Admin access uses the Worker secret ADMIN_UIDS.
- Moderation review endpoints are restricted to Firebase UIDs listed in the Worker secret ADMIN_UIDS.

### Hidden AI
- Llama Guard 3 8B checks message safety.
- GLM-4.7-Flash performs a second risk-triage pass for grooming/predatory contact, sexual solicitation, self-harm, threats, personal contact details, off-platform contact requests, coercion, and spam. Risk or uncertainty sends a message to manual review.
- GLM-4.7-Flash also classifies language, mood, and theme for internal metadata.
- GLM-4.7-Flash translates a letter only when an authenticated participant requests a translation.
- The models never compose a letter on behalf of a pilot.
- AI is a screening aid, not a safety guarantee. It can miss harmful content or flag harmless content. Human review, reporting, blocking, rate limits, and clear community rules remain necessary.

## Important safety gate — do not remove casually

Every new pilot starts with age_band = UNVERIFIED and age_verified = 0. Sending and matching are blocked until a trusted age-assurance process has verified the band as UNDER_18 or ADULT. Matching is same-band only. This protects minors from being randomly paired with adults, but it is not sufficient by itself: the chosen age-assurance provider, parental/guardian requirements where applicable, human moderation coverage, and launch jurisdiction rules still need to be reviewed before opening the service.

There is deliberately no self-declared-age endpoint and no shortcut in the app. A trusted age-assurance provider and a signed provider callback still need to be selected and integrated. Do not set age_verified=1 manually for production users.

## Firebase setup

1. Open the existing Firebase project.
2. In Authentication → Sign-in method, enable Anonymous, Email/Password, and Google.
3. Enable Firebase Cloud Messaging and Google Analytics for the Android app.
4. The Android app package is com.nexauren.paper_plane. The supplied client configuration is stored at firebase/google-services.json and copied into android/app/google-services.json by the Android build workflow.
5. The workflow reads the Firebase API key, Android App ID, project number, Project ID, and Web OAuth client ID from that file. It configures the Google Services Gradle plugin and passes the values into the Flutter build. No manual Dart defines are needed for GitHub Actions.
6. Google sign-in uses the Web OAuth client (oauth_client client_type 3) from the Firebase file. Add the SHA-1 and SHA-256 fingerprints for the certificate used to sign the APK in Firebase Project settings → Your apps → Android app, then download a fresh google-services.json and replace firebase/google-services.json. The current uploaded file has the Web OAuth client, but no Android OAuth client entry yet; Google sign-in can fail until the signing fingerprint is registered.
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

## Flutter build

GitHub Actions generates the Android platform, copies firebase/google-services.json into android/app, configures the Google Services Gradle plugin, extracts the public Firebase client values, runs the widget tests, and builds the release APK. The build also sets PAPER_PLANE_API_BASE_URL to the deployed Worker endpoint.

For a local build, use the same Firebase values from firebase/google-services.json as Dart defines: FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID, FIREBASE_PROJECT_ID, and GOOGLE_SERVER_CLIENT_ID. The Android Google Services Gradle plugin and google-services.json must also be present under android/app.

## Pages

Pages remains the public website. Use a Worker custom domain such as api.yourdomain.example for the API, and set that exact site origin in APP_ORIGINS. Do not point the mobile app at the Pages website URL unless Pages is deliberately configured to proxy the Worker API.

## Known work still required before public release

- Add the signing certificate SHA-1 and SHA-256 fingerprints to Firebase and refresh firebase/google-services.json before validating Google sign-in on the signed release APK.
- Create the D1 database and Queue resources in the correct Cloudflare account.
- Select and integrate a trusted age-assurance provider and signed callback. This is currently a hard release blocker: all new users are UNVERIFIED and cannot send or receive random mail until this is complete.
- Build the human moderation dashboard/workflow on top of the admin endpoints and define response coverage and escalation procedures.
- Verify local laws, privacy notice, data-retention and deletion process, and child-safety requirements for each launch region.
- Connect live API data to every visual screen; the composer, auth, notification registration, and API clients are prepared, but inbox, Open Sky, profile, collection, and some other visual screens still show illustrative content.
- Test FCM delivery on a real Android device and configure notification channels.
- Add integration tests using Firebase Auth and Cloudflare staging resources before production.
