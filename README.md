# Paper Plane

**Send a message to a stranger.**

An Android-first Flutter application built with Dart, following the supplied Paper Plane visual references: a midnight-blue sky, warm gold highlights, paper letters, paper-plane flight motion, Open Sky, pilot profile, collection, and safety screens.

## Current branch

The active integration branch is **platform-integration**. It is based on the Flutter UI foundation and keeps the original main branch unchanged.

## Flutter application

- Welcome and home experience with animated paper-plane artwork.
- Write-a-plane composer with a 200-character limit, mood, audience, destination, and reply preference.
- Flight-state screen with a clear distinction between illustrative preview data and server state.
- Inbox, sealed incoming plane, and opened paper letter.
- Open Sky, pilot profile, collection, invite, settings, and safety screens.
- Firebase runtime, anonymous pilot identity, authenticated Worker API client, and opt-in FCM registration service.

## Backend preparation

- Firebase Authentication verifies the pilot identity.
- Cloudflare Worker is the API and business-rules layer.
- Cloudflare D1 is the primary relational store.
- Cloudflare Queues handle asynchronous matching and delivery.
- Workers AI operates internally for safety checks, risk triage, metadata classification, and translation. It does not compose messages for users.
- Cloudflare Pages remains the public website; the Android app connects to the Worker API.

See **[Platform integration setup](docs/PLATFORM_INTEGRATION.md)** for Firebase configuration, Cloudflare resource creation, secrets, deployment, and Flutter build commands.

## Run locally

Generate the Android platform folder once, then install dependencies:

~~~bash
flutter create --platforms=android --project-name paper_plane --org com.nexauren .
flutter pub get
~~~

The Firebase and Worker values are supplied at build time. Follow the integration guide before running a network-enabled build.

## Current implementation status

The Dart UI and integration clients are committed, and the Worker API plus D1 migration are prepared. The repository still requires the owner's Firebase project configuration, a real D1 database ID, Cloudflare Queue resources, Worker secrets, and deployment. Until those are configured, the app can run in UI preview mode but cannot deliver letters to real pilots.

**Safety gate:** new users are age-unverified by default. Sending and random matching remain blocked until a trusted age-assurance process is integrated. Users are only matched within the same verified age band. AI screening is not a safety guarantee; human moderation and reporting procedures are required before public launch.

Events remain outside this first implementation and are planned for a later phase.
