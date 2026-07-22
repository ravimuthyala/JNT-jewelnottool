# Built-in Kotlin plugin compatibility follow-up

Date checked: July 20, 2026

## Summary

- `sentry_flutter`
  - Current project version: `8.14.2`
  - Latest available version checked: `9.24.0`
  - Result: upgrading to `9.24.0` fixes the immediate Kotlin `languageVersion = "1.6"` compiler failure, but the latest plugin still uses its own Android Kotlin Gradle setup instead of Flutter Built-in Kotlin.
  - Upstream repo: https://github.com/getsentry/sentry-dart
  - Issue tracker: https://github.com/getsentry/sentry-dart/issues

- `nfc_manager`
  - Current project version: `3.5.1`
  - Latest available version checked: `4.2.1`
  - Result: latest version still uses its own Android Kotlin Gradle setup instead of Flutter Built-in Kotlin, so there is no fully Built-in-Kotlin-ready version to upgrade to right now.
  - Upstream repo: https://github.com/okadan/flutter-nfc-manager
  - Issue tracker: https://github.com/okadan/flutter-nfc-manager/issues

- `shared_preferences_android`
  - Current project version: `2.4.23`
  - Latest available version checked: `2.4.27`
  - Result: latest version no longer applies `kotlin-android` in the `plugins` block, but it still declares the Kotlin Gradle plugin in `buildscript` and uses Kotlin compiler configuration, so there still does not appear to be a fully Built-in-Kotlin-ready release.
  - Upstream repo: https://github.com/flutter/packages
  - Issue tracker: https://github.com/flutter/packages/issues

- `url_launcher_android`
  - Current project version: `6.3.30`
  - Latest available version checked: `6.3.32`
  - Result: latest version no longer applies `kotlin-android` in the `plugins` block, but it still declares the Kotlin Gradle plugin in `buildscript` and uses Kotlin compiler configuration, so there still does not appear to be a fully Built-in-Kotlin-ready release.
  - Upstream repo: https://github.com/flutter/packages
  - Issue tracker: https://github.com/flutter/packages/issues

## Draft issue: sentry_flutter

Title: `sentry_flutter` Android plugin is not yet migrated to Flutter Built-in Kotlin

Body:

```md
Flutter's Built-in Kotlin migration currently requires Android plugins to stop applying their own Kotlin Gradle plugin/configuration and rely on Flutter's built-in Kotlin support instead.

I checked `sentry_flutter` on July 20, 2026 while migrating a Flutter app to Built-in Kotlin.

- Current app failure originally came from `sentry_flutter 8.14.2`, whose Android build config still sets `languageVersion = "1.6"`, which no longer works with newer Kotlin toolchains.
- Upgrading to `sentry_flutter 9.24.0` removes that specific `languageVersion = "1.6"` blocker, but the plugin still contains its own Android Kotlin Gradle setup in `android/build.gradle`:
  - `buildscript { ... kotlin-gradle-plugin ... }`
  - `apply plugin: 'kotlin-android'`
  - plugin-managed `kotlinOptions`

That means there still doesn't appear to be a `sentry_flutter` release that fully supports Flutter Built-in Kotlin yet.

Flutter migration guide for app developers:
https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers

Flutter migration guide for plugin authors:
https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors

Could you migrate the Android part of `sentry_flutter` to Built-in Kotlin compatibility?
```

## Draft issue: nfc_manager

Title: `nfc_manager` Android plugin is not yet migrated to Flutter Built-in Kotlin

Body:

```md
I checked `nfc_manager` on July 20, 2026 while migrating a Flutter app to Built-in Kotlin.

The latest version I checked was `4.2.1`, and its Android plugin still appears to manage Kotlin directly in `android/build.gradle.kts`:

- plugin applies `id("kotlin-android")`
- plugin declares Kotlin Gradle plugin in `buildscript`
- plugin sets plugin-local `kotlinOptions`

Because of that, I couldn't find a `nfc_manager` release that fully supports Flutter Built-in Kotlin yet.

Flutter migration guide for app developers:
https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers

Flutter migration guide for plugin authors:
https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors

Could you migrate the Android plugin to Built-in Kotlin compatibility?
```

## Draft issue: shared_preferences_android

Title: `shared_preferences_android` is not fully migrated to Flutter Built-in Kotlin

Body:

```md
I checked `shared_preferences_android` on July 20, 2026 while migrating a Flutter app to Built-in Kotlin.

The latest version I checked was `2.4.27`.

It looks closer to the new model than older releases because it no longer applies `kotlin-android` in the `plugins` block, but it still appears to manage Kotlin directly in `android/build.gradle.kts`:

- `buildscript` still declares `org.jetbrains.kotlin:kotlin-gradle-plugin`
- plugin still configures Kotlin compiler options directly

Because of that, there still doesn't appear to be a fully Built-in-Kotlin-ready release yet from an app developer perspective.

Flutter migration guide for app developers:
https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers

Flutter migration guide for plugin authors:
https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors

Could you confirm the intended migration path here, or complete the Built-in Kotlin migration if more work is still required?
```

## Draft issue: url_launcher_android

Title: `url_launcher_android` is not fully migrated to Flutter Built-in Kotlin

Body:

```md
I checked `url_launcher_android` on July 20, 2026 while migrating a Flutter app to Built-in Kotlin.

The latest version I checked was `6.3.32`.

It looks closer to the new model than older releases because it no longer applies `kotlin-android` in the `plugins` block, but it still appears to manage Kotlin directly in `android/build.gradle.kts`:

- `buildscript` still declares `org.jetbrains.kotlin:kotlin-gradle-plugin`
- plugin still configures Kotlin compiler options directly

Because of that, there still doesn't appear to be a fully Built-in-Kotlin-ready release yet from an app developer perspective.

Flutter migration guide for app developers:
https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers

Flutter migration guide for plugin authors:
https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors

Could you confirm the intended migration path here, or complete the Built-in Kotlin migration if more work is still required?
```
