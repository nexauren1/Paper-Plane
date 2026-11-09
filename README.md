# Paper Plane

**Send a message to a stranger.**

Paper Plane is an Android-first Flutter application written in Dart. Version 0.0.1 focuses on international paper-plane journeys, a translated inbox, live private conversations, visual flight experiences and a public sky.

## First release scope

The first release concentrates on the full message journey instead of optional extras:

- Firebase account creation and sign-in with email/password or Google.
- Server-backed pilot profile with unique handle, country and self-declared date of birth (only birth year and derived age group are retained).
- First-flight workshop with a saved server-side draft and three paper-plane designs.
- Short paper messages (up to 200 characters), random matching and public Open Sky posts.
- Server-side matching, delivery status, flight route and progress.
- Real inbox, opening and reading letters, private airplane replies, hearts and public replies.
- Automatic translation of incoming airplanes into the recipient's preferred language, with the source text always available.
- On-demand AI translation of private Chat and Chama messages, with per-message original/translation switching.
- AI-assisted content screening with a human-review queue for uncertain cases.
- Report categories, sender blocking and age-band separation for stranger matching.
- Android push notifications, an in-app foreground notification banner and shortcuts to the exact incoming airplane or Chama.
- A worldwide friends list with pilot-handle search, friend requests and shareable invite links.
- Chama private chat, activated only after a private airplane reply is delivered to the original sender.
- An offline multiple-choice Quiz with Geography, Nature and Culture categories.
- Categorized support requests with a private ticket history.

The animated flight globe is included in the flight tracker. It uses estimated routes between country reference points, not GPS or live physical aircraft data. Chama is a private one-to-one chat that appears only after a reply airplane is delivered; adding a friend alone does not start a conversation. Friend search and random matching remain within the same self-declared age group. The Quiz runs locally and does not need an account or network after the app has loaded. Events, paid golden planes and the separate Admin APK remain later-phase work.

## Architecture

- **Flutter/Dart:** Android interface, animation, navigation and client logic.
- **Firebase Authentication:** account identity and signed Firebase ID tokens.
- **Cloudflare Worker:** authenticated API, moderation, matching, delivery and notification dispatch.
- **Cloudflare D1:** pilot profiles and preferred languages, airplanes, inbox, cached airplane/chat translations, friendships, Chama conversations and messages, reports, support tickets and audit events.
- **Cloudflare Queues and scheduled Worker tasks:** asynchronous matching and flight delivery. Matching is retried each minute while a recipient is not available; same-country symbolic flights have a 90-second minimum duration, while longer routes use an estimated duration based on distance. Daily sending is unlimited; account activity is still rate-limited to 10 airplanes and public replies combined per rolling hour, and repeated identical messages are throttled. Unmatched random airplanes expire after 24 hours, unresolved safety reviews after 72 hours, public Open Sky airplanes after 7 days, and received letters after 24 hours unopened or 48 hours after opening.
- **Workers AI:** Meta M2M100 1.2B translates received airplanes and chat messages into the recipient's preferred language. Original text is preserved and translations are cached in D1. The model translates text; it does not compose personal messages or impersonate pilots.
- **Firebase Cloud Messaging:** Android delivery and Chama notifications. After enabling notifications in Settings and configuring the Worker FCM service-account secret, Android push alerts and in-app foreground alerts identify the incoming airplane or new Chama message.

## Repository layout

- `lib/` — Flutter/Dart application.
- `cloudflare/worker/` — API, D1 migrations and backend validation.
- `firebase/google-services.json` — Android Firebase client configuration.
- `.github/workflows/android.yml` — Flutter tests and signed release APK build.
- `.github/workflows/deploy-worker.yml` — D1 migration validation, remote migration and Worker deployment.
- `docs/` — deployment, privacy and integration notes.

## Build Android

The GitHub Actions Android workflow generates the Android platform project if needed, installs dependencies, runs Flutter tests, configures release signing from repository Actions secrets, and builds the release APK.

The signing secrets are:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Firebase build values are read from `firebase/google-services.json` by the workflow. Do not commit private signing keys, Firebase service-account JSON or other server secrets to the repository.

## Deploy the Worker

The Worker deployment workflow runs when files under `cloudflare/worker/` change on `main`. It:

1. Installs Worker dependencies.
2. Applies all migration files in order to a local SQLite validation database.
3. Type-checks the Worker.
4. Applies pending migrations to the configured remote D1 database.
5. Deploys the Worker.

Cloudflare credentials are supplied through GitHub Actions secrets. Runtime integrations may also require the Cloudflare Worker secrets `FCM_SERVICE_ACCOUNT_JSON` and `ADMIN_UIDS`. A successful Worker deployment proves that the code and migrations deployed; it does not prove that every optional provider secret is present or that a real device has received a push notification.

## Safety and release checks

- Users declare their date of birth in the profile form. The Worker calculates an age group and retains only the birth year, declared group and declaration timestamp. This is self-declaration, not identity or age verification.
- Random matching keeps users in the same self-declared age group, and respects account status, consent, and block relationships. The declared group can be inaccurate and is not proof.
- AI moderation is not proof that a user is safe or that a message is harmless. Concrete risk flags are held for human review; inconclusive or unavailable moderation returns a retryable error and does not store the plane. Reports remain available to users.
- AI risk signals must be treated as review cues, not a conclusion that a user has lied about age.
- User reports and support tickets are stored separately. Only authorized admin UIDs can access moderation/support administration endpoints.
- Before public release, verify the FCM service-account secret, Cloudflare queue/cron configuration, Firebase OAuth SHA fingerprints, local age-related requirements and real-device behaviour.

## Development

```bash
flutter create --platforms=android --project-name paper_plane --org com.nexauren .
flutter pub get
flutter test
flutter build apk --release
```

See [Platform integration setup](docs/PLATFORM_INTEGRATION.md) and [AI processing and privacy](docs/PRIVACY_AI_PROCESSING.md) for configuration and data-handling details.
