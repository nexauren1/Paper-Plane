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
- Reports and administrative review records are stored in D1.
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
2. In Authentication → Sign-in method, enable Anonymous.
3. Enable Firebase Cloud Messaging for the Android app.
4. Register the Android application ID com.nexauren.paper_plane in the Firebase project.
5. Copy the non-secret client configuration values from Project settings → Your apps: Web API key, Android App ID, Messaging Sender ID / project number, and Project ID.
6. Build the app with the Dart defines shown below. These values identify the Firebase app; they are not service-account credentials.
7. In Settings, the pilot can opt into notifications. The service registers the FCM token with the Worker.

The Firebase Flutter plugins currently used by the repository are firebase_core 5.1.0, firebase_auth 7.0.1, and firebase_messaging 17.0.1. The code initializes Firebase from explicit FirebaseOptions so no real app config needs to be committed. Re-run the Firebase setup/configuration when registering another platform or changing Firebase products.

## Cloudflare setup

From cloudflare/worker:

~~~~bash
npm install
npx wrangler login
npx wrangler d1 create paper-plane-db
npx wrangler queues create paper-plane-delivery
npx wrangler queues create paper-plane-delivery-dlq
~~~~

Copy the D1 database ID returned by the first command into wrangler.jsonc. Replace FIREBASE_PROJECT_ID, APP_ORIGINS with the exact Pages website origin(s), comma-separated, and database_id with the actual D1 ID.

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

## Flutter build

From the repository root:

~~~~bash
flutter pub get
flutter run \
  --dart-define=FIREBASE_API_KEY=YOUR_FIREBASE_WEB_API_KEY \
  --dart-define=FIREBASE_APP_ID=YOUR_ANDROID_FIREBASE_APP_ID \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_FIREBASE_PROJECT_NUMBER \
  --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID \
  --dart-define=PAPER_PLANE_API_BASE_URL=https://YOUR_WORKER_API_DOMAIN
~~~~

For a release APK, use the same defines with flutter build apk --release. Keep the Firebase API key and app identifiers in the app's normal Firebase configuration; never put a Cloudflare API token, service-account private key, or FCM service-account JSON in the Android application.

## Pages

Pages remains the public website. Use a Worker custom domain such as api.yourdomain.example for the API, and set that exact site origin in APP_ORIGINS. Do not point the mobile app at the Pages website URL unless Pages is deliberately configured to proxy the Worker API.

## Known work still required before public release

- Fill in the real Firebase Project ID, app IDs, API key, and Worker custom domain locally.
- Create the D1 database and Queue resources in the correct Cloudflare account.
- Select and integrate a trusted age-assurance provider and signed callback.
- Build the human moderation dashboard/workflow and define response coverage and escalation procedures.
- Verify local laws, privacy notice, data-retention and deletion process, and child-safety requirements for each launch region.
- Connect live API data to every visual screen; some screens still show illustrative content.
- Test FCM delivery on a real Android device and configure notification channels.
- Add integration tests using Firebase Auth and Cloudflare staging resources before production.
