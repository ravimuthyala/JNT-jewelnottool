# Nail Measurement API — Play Store Release Precautions

The nail measurement feature (`NailMeasurementService`, `FullHandMeasurementService`)
calls an AWS API Gateway + Lambda endpoint that costs money per invocation
(compute time + API Gateway requests). Right now, for local dev convenience,
the API key and `ENABLE_*` flags are **hardcoded as `defaultValue`s** in:

- `lib/services/nail_measurement_service.dart`
- `lib/services/full_hand_measurement_service.dart`

so plain `flutter run` works without typing `--dart-define` flags every time.
**This is a test-only shortcut and must not ship to the Play Store as-is.**

## Before building the real release (`flutter build appbundle`)

1. **Rotate the API key.** The key currently hardcoded in source
   (`HOGfjqLWN1I8...`) has been sitting in a dev machine's shell history,
   `.vscode/launch.json`, and now the Dart source itself. Generate a new one
   in API Gateway before the first public release and update it everywhere
   at once (server usage plan + client defines).

2. **Move the key out of hardcoded `defaultValue`s.** Use
   `--dart-define-from-file` with a gitignored JSON file instead of typing
   `--dart-define=...=<key>` (which leaks into shell history) or leaving it
   as a compiled-in default:

   ```json
   // env/production.json  (add to .gitignore, never commit)
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

- [ ] API key rotated from the one used during development
- [ ] Key supplied via `--dart-define-from-file` with a gitignored file, not
      committed anywhere (source, `launch.json`, or this repo's history)
- [ ] API Gateway usage plan has a `Quota` and `RateLimit` set
- [ ] CloudWatch alarm configured for request-count/error spikes on this API
- [ ] Confirmed debug endpoints aren't reachable from the production client build
