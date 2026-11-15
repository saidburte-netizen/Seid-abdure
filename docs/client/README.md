# Client handover pack — Brade and Cake House v1.0.8

| File | Audience | Purpose |
| --- | --- | --- |
| `CLIENT_USER_GUIDE.md` | Staff and administrators | Install, sign in, daily workflows, messages |
| `FEATURES.md` | Owner and administrators | What the app does, role access, what is not included |
| `SUPPORT.md` | Administrator / first-line support | Who to contact, what to collect, known limitations |
| `PRIVACY_POLICY.md` | Owner, staff, customers | What is stored on the device and in the database |

Before handing this pack over, the owner should:

1. Replace `support@bradeandcakehouse.example` with the real support address.
2. Apply the three `supabase/migrations/20261115*` SQL files in the Supabase
   SQL Editor (in filename order) and keep the output.
3. Decide whether the GitHub repository stays public.
4. Configure the Android signing secrets if a signed release is required;
   otherwise state clearly that the APK is a sideload/testing build.
5. Read `docs/AUDIT_REPORT.md` for the verified/unverified status of every
   release check.
