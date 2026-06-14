# jnt_app_0120

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firestore account migration (users -> typed collections)

This repo includes a one-time migration script:

- `scripts/migrate_users_to_typed_collections.js`

It reads from `users` and routes each document to one of:

- `client`
- `artist`
- `client_artist`
- `company`

Routing is based on `roles` (fallback: existing `accountType`).

### Run

1. Install script deps:
   - `cd scripts && npm install`
2. Dry-run first:
   - `node migrate_users_to_typed_collections.js --service-account /ABSOLUTE/PATH/serviceAccount.json`
3. Apply migration:
   - `node migrate_users_to_typed_collections.js --service-account /ABSOLUTE/PATH/serviceAccount.json --apply`

Optional flags:

- `--verbose`: print per-document actions
- `--overwrite`: overwrite destination docs if already present
- `--delete-source`: delete source docs from `users` after successful migrate (requires `--apply`)
- `--source-collection <name>`: use a different source collection

## Seed dummy artists (Goldsmith + sponsorship request)

This repo includes a seed script for test data:

- `scripts/create_dummy_artists_goldsmith.js`

It upserts exactly 3 artist docs with:

- `ascension.tier = Goldsmith`
- `ascension.levelName = Goldsmith`
- `ascension.sponsorshipEligible = true`
- `sponsorshipRequest.tier = Goldsmith`

Run:

1. Install script deps:
   - `cd scripts && npm install`
2. Dry-run first:
   - `node create_dummy_artists_goldsmith.js --service-account /ABSOLUTE/PATH/serviceAccount.json --verbose`
3. Apply seed:
   - `node create_dummy_artists_goldsmith.js --service-account /ABSOLUTE/PATH/serviceAccount.json --apply --verbose`
