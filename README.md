# Paper Plane

**Send a message to a stranger.**

Paper Plane is an Android-first Flutter application written in Dart. It turns short messages into paper-plane journeys between pilots, with an animated first launch, a private inbox, replies and a public sky.

## First release scope

The first release concentrates on the full message journey instead of optional extras:

- Firebase account creation and sign-in with email/password or Google.
- Server-backed pilot profile with unique handle, country and self-declared date of birth (only birth year and derived age group are retained).
- First-flight workshop with a saved server-side draft and three paper-plane designs.
- Short paper messages (up to 200 characters), random matching and public Open Sky posts.
- Server-side matching, delivery status, flight route and progress.
- Real inbox, opening and reading letters, private airplane replies, hearts and public replies.
- AI-assisted content screening with a human-review queue for uncertain cases.
- Report categories, sender blocking and age-band separation for stranger matching.
- Android push notifications, an in-app foreground notification banner and a shortcut to the inbox.
- Categorized support requests with a private ticket history.

The private chat/“Chama” screen is only a labelled preview and is not part of the first release. Events, paid golden planes, the separate Admin APK and extended globe features remain later-phase work.

## Architecture

- **Flutter/Dart:** Android interface, animation, navigation and client logic.
- **Firebase Authentication:** account identity and signed Firebase ID tokens.
- **Cloudflare Worker:** authenticated API, moderation, matching, delivery and notification dispatch.
- **Cloudflare D1:** pilot profiles, airplanes, inbox, reports, support tickets and audit events.
- **Cloudflare Queues and scheduled Worker tasks:** asynchronous matching and flight delivery.
- **Workers AI:** content-safety checks, risk triage, classification and translation. It does not write personal messages for pilots.
- **Firebase Cloud Messaging:** Android delivery notifications.

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
- AI moderation is not proof that a user is safe or that a message is harmless. Uncertain items go to review; reports remain available to users.
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
