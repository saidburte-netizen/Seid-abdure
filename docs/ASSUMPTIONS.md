# Assumptions

- The business operates one or more branches in Ethiopia and records must be
  branch-scoped from the outset.
- Ethiopian Birr (ETB) is the default currency. Tax rates and statutory payroll
  deductions are configurable and must be reviewed locally before production
  use.
- Supabase credentials are supplied at deployment time through environment
  variables or GitHub Actions secrets; no credentials belong in source control.
- Admin web publishing and mobile signing require owner-managed credentials and
  are not configured in this repository.
- Auth is invite-only. The first authenticated user may claim owner access
  through the onboarding screen while no active membership exists. Later users
  are assigned by an administrator.
- The official logo is the file supplied by the business. It must not be
  redrawn or recoloured; generated foreground/notification variants are derived
  from it only by padding or monochrome masking.
- Local SQL validation uses PostgreSQL with stubbed `auth`/`storage` schemas
  because the Supabase CLI/Docker stack is not available in the development
  environment. Production CI uses the real Supabase CLI.
- Any GitHub token pasted into chat, a terminal, an issue or a commit must be
  revoked and replaced. The repository remote must not contain a plaintext
  token.
