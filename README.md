# Paper Plane

**Send a message to a stranger.**

Paper Plane is an Android-first Flutter application built with Dart. This branch contains the first native Flutter UI foundation based on the 26 visual references supplied by the project owner.

## Screens included

- Welcome screen with animated paper plane
- Home dashboard and bottom navigation
- Write a Plane composer with a 200-character limit, mood, visibility, destination, and reply setting
- Flight progress and route presentation
- Inbox, incoming plane, and opened letter
- Open Sky public-message cards
- Pilot profile and local settings
- Invite and share screen
- Collection / passport-style screen
- Weekly country feature
- Safety and privacy information screen

## Run locally

```bash
flutter pub get
flutter run
```

## Important implementation status

This is a UI foundation with local demonstration data. It does **not** yet deliver messages to real users. Authentication, matching, D1 persistence, Cloudflare Worker API calls, moderation, push notifications, real QR invites, and backend-backed profile statistics must be integrated and tested before release.

The UI is recreated with real Flutter widgets and Dart custom painters, not by placing flattened screenshots over the interface. This keeps navigation, forms, cards, and transitions interactive and responsive.

Events are intentionally excluded from this first version and remain a future phase.
