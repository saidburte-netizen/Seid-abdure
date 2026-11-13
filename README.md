# Bread & Cake Management

A Flutter and Supabase starter for bakery and shop operations in Ethiopia.
The repository is at the foundation stage: the responsive dashboard shell,
theme, route structure, English/Amharic/Afaan Oromo message catalogs, and
Flutter/Supabase CI workflows are in place. Operational modules are not yet
implemented; see [docs/PLAN.md](docs/PLAN.md).

## Requirements

- Flutter stable (Dart 3.3 or later)
- Supabase CLI and Docker for local database work
- A Supabase project for deployed environments

## Local development

```sh
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key
```

Start the local Supabase stack and apply migrations when database migrations
are added:

```sh
supabase start
supabase db reset
supabase test db
```

## CI

GitHub Actions runs Flutter formatting, analysis, tests, and a web build.
Database workflows start Supabase locally, reset the database, and run SQL
regression tests. Android and web build artifacts are generated manually or on
version tags. Deployment and Android signing are intentionally not enabled
without owner-provided secrets.

## Configuration and security

Do not commit Supabase keys, GitHub tokens, signing keys, or service-role
credentials. Configure deployment credentials as GitHub Actions secrets and
runtime configuration through the platform's environment configuration. A
service-role key must never be embedded in the Flutter client.

Authentication is invite-only: create users through Supabase Auth and provide
their credentials securely. The database creates a profile when an Auth user
is added. An administrator must assign an active branch membership and role;
module routes require the corresponding role permission. The Flutter client
uses only the public anon key and database row-level security remains the
enforcement boundary.

## Current functionality

The app currently provides the localized navigation shell and routes to
roadmap placeholders. It is not yet suitable for recording real sales,
inventory, employee, or financial data. See [docs/ASSUMPTIONS.md](docs/ASSUMPTIONS.md)
and [docs/PLAN.md](docs/PLAN.md) before extending it.
