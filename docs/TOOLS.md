# Toolchain

| Tool | Version used |
| --- | --- |
| Flutter | 3.35.4 (stable) |
| Dart | 3.9.2 |
| Java | Temurin 17 |
| Android Gradle plugin | 8.9.1 |
| Gradle wrapper | 8.12 |
| Supabase CLI | latest in CI (database inspection only) |
| PostgreSQL / Supabase | live project `nmrpmypgkljmtnsvmcfn` |
| Python (schema generation) | 3.x |

## Local commands

```sh
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
flutter build web --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

Only `SUPABASE_URL` and `SUPABASE_ANON_KEY` are read at build time. The app
never reads or embeds a service-role key.
