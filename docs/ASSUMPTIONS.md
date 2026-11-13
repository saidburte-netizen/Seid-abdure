# Assumptions

- The first deployment is for one Ethiopian business that may operate multiple
  branches; records must be branch-scoped from the outset.
- Ethiopian Birr (ETB) is the default currency. Tax rates and statutory payroll
  deductions must be configurable and reviewed locally before production use.
- Supabase project credentials are supplied at deployment time through
  environment variables or GitHub Actions secrets; no credentials belong in
  source control.
- Admin web publishing and mobile signing require owner-managed credentials and
  are not configured in this repository.
- This repository was initially empty. A complete ERP across all listed modules
  requires incremental implementation and review; the current scaffold is not a
  production-ready operational system.
- No GitHub token pasted into chat is used. Any exposed token must be revoked
  and replaced via GitHub's secret-management facilities.
