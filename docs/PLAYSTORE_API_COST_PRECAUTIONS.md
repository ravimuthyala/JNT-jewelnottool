# Nail Measurement API — Play Store Release Precautions

The nail measurement feature (`NailMeasurementService`, `FullHandMeasurementService`)
calls a third-party (AWS-hosted, vendor-operated) API Gateway + Lambda
endpoint that costs money per invocation (compute time + API Gateway
requests). It is not part of JNT's own AWS account/infrastructure — treat it
as an external vendor relationship, the same as Stripe or Shippo.

**Update:** the API key and `ENABLE_*` flags used to be **hardcoded as
`defaultValue`s** directly in source (`lib/services/nail_measurement_service.dart`,
`lib/services/full_hand_measurement_service.dart`) and duplicated in
`.vscode/launch.json`, so plain `flutter run` worked without typing
`--dart-define` flags. That leaked a real key into source control. This has
been fixed: those `defaultValue`s are now empty strings, and all configuration
(including the key) is supplied via `--dart-define-from-file` pointing at a
gitignored `env/<flavor>.json` file — see `env/example.json` for the
template. **The one thing this fix could NOT do** is invalidate the old key
itself — that still requires the vendor (see step 1 below).

## Before building the real release (`flutter build appbundle`)

1. **Rotate the API key — STILL PENDING, requires the vendor.** The old key
   (`HOGfjqLWN1I8...`) was sitting in a dev machine's shell history,
   `.vscode/launch.json`, and the Dart source itself — all committed to this
   repo's history — so it must be treated as compromised regardless of the
   code fix above. Contact the vendor operating this measurement API and
   request a new key (and confirm a request quota/rate limit is set on it —
   see the cost-control section below). This is not something that can be
   done from this codebase alone.

2. **Move the key out of hardcoded `defaultValue`s — DONE.** Configuration
   now comes from `--dart-define-from-file` with a gitignored per-flavor
   JSON file instead of an inline `--dart-define=...=<key>` (which leaks
   into shell history) or a compiled-in default:

   ```json
   // env/production.json  (gitignored -- copy env/example.json to create it)
   {
     "ENV": "production",
     "ENABLE_NAIL_MEASUREMENT_API": true,
     "ENABLE_FULL_HAND_MEASUREMENT_API": true,
     "NAIL_MEASUREMENT_API_KEY": "<rotated key>",
     "FULL_HAND_MEASUREMENT_API_KEY": "<rotated key>"
   }
   ```

   ```bash
   flutter build appbundle --dart-define-from-file=env/production.json
   ```

   `.vscode/launch.json`'s dev/uat/production configurations already do this
   (`--dart-define-from-file=env/<flavor>.json`) instead of inline
   `--dart-define=...API_KEY=...`. Once the key is rotated (step 1), paste
   the new value into your local `env/dev.json` / `env/uat.json` /
   `env/production.json` — those files are gitignored, so this never touches
   source control again.

3. **Understand `--dart-define` is not a secret vault.** Whatever value you
   pass — file-based or hardcoded — ends up as a plain compiled constant in
   the shipped APK/AAB. Anyone can decompile the app and extract the API
   key. Treat it as "obfuscated," not "secret."

## Reducing API cost / abuse risk once shipped publicly

The single biggest risk once the key is embedded in every install: someone
extracts it and calls your AWS endpoint directly, off-app, at whatever
volume they want — you pay for all of it.

- **API Gateway usage plan + throttling.** Set a `RateLimit`/`BurstLimit`
  and a `Quota` (requests/day or /month) on the usage plan tied to this API
  key, so a leaked key can't run up an unbounded bill.
- **Per-key request quota alerting.** Set a CloudWatch alarm on
  `Count`/`4XXError` for this API stage so an unusual spike (key abuse)
  pages you before the bill does.
- **Payload size cap.** Already enforced client-side
  (`_maxPayloadBytes`), but confirm API Gateway / Lambda also caps request
  body size server-side — don't rely on the client being well-behaved.
- **Consider a server-side proxy for the real release.** The durable fix
  for "key embedded in every APK" is to never ship the AWS key to the
  client at all: proxy these calls through your own backend (Supabase edge
  function, or a thin Lambda in front of this one) that holds the real key
  server-side and does its own per-user rate limiting (e.g. keyed by
  Supabase auth session). Only worth the engineering cost once real usage
  volume/cost risk justifies it — flag if this becomes a priority.
- **Lambda concurrency limit.** Cap `ReservedConcurrentExecutions` on the
  measurement Lambda so a traffic spike (legitimate or abusive) can't
  scale cost linearly with request volume.
- **Remove/disable debug endpoints in production.** `/measure/full-hand-two-shot-debug`
  and similar debug variants do extra work (writing annotated debug
  images) — make sure the client never calls these in a release build, and
  ideally gate them off entirely server-side outside of dev/staging.

## Checklist before submitting to Play Console

- [ ] API key rotated from the one used during development — **pending,
      requires the vendor**
- [x] Key supplied via `--dart-define-from-file` with a gitignored file, not
      committed anywhere (source, `launch.json`, or this repo's history) —
      done; hardcoded `defaultValue`s removed from both services, inline
      `--dart-define=...API_KEY=...` removed from `.vscode/launch.json`,
      `env/*.json` gitignored with `env/example.json` committed as a template
- [ ] API Gateway usage plan has a `Quota` and `RateLimit` set — pending,
      requires the vendor
- [ ] CloudWatch alarm configured for request-count/error spikes on this API
      — pending, requires the vendor
- [ ] Confirmed debug endpoints aren't reachable from the production client
      build
