# Paper Plane — privacy and AI processing notice draft

This is an implementation note for the privacy policy, not a substitute for legal review.

## What happens to a letter

1. The sender writes plain text. Paper Plane accepts a maximum of 200 characters.
2. The authenticated app sends the letter to the Paper Plane Cloudflare Worker over HTTPS.
3. The Worker checks the Firebase ID token, daily-send limit, duplicate/rate checks, recipient restrictions, and moderation result.
4. The letter is saved in Cloudflare D1 only after the application rules and safety checks have run.
5. Random letters are matched only to a user in the same age group derived from the sender's self-declared date of birth. This is a cohort-separation safeguard, not proof of identity or age. If no eligible user exists, the letter remains queued.
6. A delivered unread letter is scheduled to expire after 24 hours. When opened, its expiry is changed to 48 hours from opening. These values are application rules and should be reviewed before launch.

## AI processing — internal, not a user-facing assistant

Paper Plane sends the text of a letter to Cloudflare Workers AI for:
- unsafe-content screening with Llama Guard;
- a second risk-triage pass for grooming/predatory contact, sexual solicitation, self-harm, threats, personal contact details, off-platform contact requests, coercion, and spam;
- language, mood, and topic metadata classification;
- translation when an authenticated participant explicitly requests it.

The AI is not used to write messages for users, create fake conversations, select a person's identity, or decide that a user is safe. When a result is unsafe, uncertain, or the model is unavailable, content is not automatically published or delivered. It is either rejected or held for review according to the API rule.

The currently selected Cloudflare AI models list zero-data-retention availability in Cloudflare's model catalogue. This does not mean Paper Plane itself stores no messages: letters are stored in D1 to provide the service, and the policy must explain the application's own storage, access, deletion, and expiry rules.

## Data categories in the current schema

- Firebase UID: internal account identifier; never displayed as the pilot's public name.
- Pilot code and fictional pilot name.
- Self-declared date of birth is used transiently by the Worker; D1 retains only the birth year, derived age group, and declaration timestamp, not the full date.
- Language and optional country code. Country display is opt-in; no precise GPS location is collected by this schema.
- Letter body, delivery state, moderation state, timestamps, and optional translation.
- FCM device token, only after a pilot opts into notifications.
- Reports, blocks, public likes, and public replies.

Push notifications use generic text and do not include the letter body.

## Before release, the public privacy policy must state

- that message text is processed by Cloudflare Workers AI for moderation and requested translation;
- where the app stores letters, for how long, and how expiration differs before and after opening;
- how the sender, recipient, moderators, and service providers can access content;
- how a user can report, block, export, and request deletion of an account and its content;
- the legal basis, transfer locations, and contact channel for privacy requests;
- how FCM tokens are stored and how notification permission can be withdrawn;
- how moderation reports and safety records are retained after a letter expires.

Do not launch until account deletion, export, report handling, human review operations, retention schedules, and the self-declared age-group safeguards are implemented and tested.
