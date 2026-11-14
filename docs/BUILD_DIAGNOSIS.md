# Build artifact diagnosis

## What was wrong

The previous workflow did not deliver one app file:

1. `build-web.yml` uploaded the directory `build/web` as the artifact. GitHub
   stores directory artifacts as ZIP archives, so the downloaded artifact
   contained `index.html`, `main.dart.js`, `assets/`, and other loose web files.
   That is a web site, not a single installable phone app.
2. `build-android.yml` built split APKs and a universal APK, then uploaded the
   whole `build/app/outputs/flutter-apk/` output folder. The artifact therefore
   contained several APK files instead of one clearly named
   `brade-cake-house.apk`.
3. The release step was not present, so there was no single Release page where
   the APK, AAB and web ZIP could be downloaded together.
4. The workflow used the moving `stable` Flutter channel. A newer stable SDK
   changed `material.dart` and broke analysis, which made the build look
   incomplete.

## What is fixed now

- There is exactly one Flutter project: one `pubspec.yaml`, one
  `lib/main.dart`, one router in `lib/app.dart`, and one set of feature screens
  imported by that router.
- `build-android.yml` builds one universal release APK and one AAB, renames them
  to `brade-cake-house.apk` and `brade-cake-house.aab`, and uploads only those
  two files.
- `build-web.yml` builds the same Flutter project for web, zips the result as
  `brade-cake-house-web.zip`, and uploads only that ZIP.
- Both workflows create/update the `v1.0.0` GitHub Release and attach the
  compiled files.
- The APK verification step fails the build if the APK is missing, smaller than
  15 MB, cannot be read by `aapt`, has the wrong package/label, or does not
  contain the bundled logo asset.
- Flutter is pinned to `3.35.4` so CI, Android and web builds use the same SDK.
