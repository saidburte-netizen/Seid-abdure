# Fix CI formatting failure + compact UI redesign

Branch: `fix/format-and-ui` (from `main` at `9cb7b3f`)
Version: `1.0.9+9`

## Why CI run #91 failed

`dart format --output=none --set-exit-if-changed lib test` found **37 of 78**
files unformatted, so CI stopped before `flutter analyze` or `flutter test` ran.

## What this branch changes

### Formatting and analyzer
- Formatted `lib` and `test` (now 81 files, **0 changed** on the check).
- Deleted the stray `lib/settings_screen.dart` duplicate (it shadowed
  `lib/screens/settings_screen.dart` and caused a project-wide
  `DataRevision` undefined error).
- Removed the duplicate `case FieldType.json:` in `CrudTab._buildField`
  (`unreachable_switch_case`).
- Added `tool/format.sh` for local use. CI only **verifies** formatting and
  never rewrites, commits, or pushes formatting changes.

### Compact UI (shared widgets, so every screen follows the same rules)
- `lib/widgets/app_ui.dart` (new):
  - `KpiStrip` / `DashboardKpiStrip`: 2–3 KPI numbers loaded from the existing
    views (`v_dashboard_kpis`); green cards, cream labels, gold numbers.
  - `AppToolbar`: one row — full-width translated search field plus
    icon-only Refresh / CSV / PDF buttons with tooltips and a gold circular
    Add action (48 dp).
  - `AppListCard`: ivory card, thin green accent, title and amount on one row,
    smaller secondary line, translated status chip, 48 dp row-actions menu.
  - `AppTabBar`: compact scrollable tabs on the green structural band, gold
    underline from the theme.
- `AppScaffold` / `ModuleScaffold`: one green header (`Key('app-header')`,
  176 dp = 22.0% of a 360×800 screen), pinned 56 dp bar, back arrow, short
  two-line title in a `FittedBox` (no truncation), small icon actions, KPI
  strip filling the expanded area. No hero, no duplicate logo, no
  “Press back” line.
- Dashboard: KPI strip, slim welcome line, tidy grid, most-used modules first.
- Settings and every module screen: KPI strip, translated labels, no
  technical text on user screens.
- Reports: removed the duplicated report name; compact picker so the first
  record stays above the 45% line.
- POS: product cards grow with the reader’s text scale instead of overflowing.

### Tests (replacing the obsolete 52–68% colour test)
- Deleted `test/colour_probe_test.dart` and added
  `test/layout_design_test.dart` (104 tests) checking, at 360×800:
  a) header ≤ 22% of screen height
  b) first record top ≤ 45% on list screens
  c) no raw localization keys or technical words (`v_`, `public.`,
     `uuid`, SQL) in rendered text
  d) no title truncation at 1.3× text scale
  e) tap targets ≥ 48 dp and no overflow
  f) green family 25–55% of pixels on screens with data (light)
  Every main screen runs in light and dark, in `en`, `am` and `om`.
  Settings sub-pages and auth routes are covered too.
- Added `test/support/sample_backend.dart` so layout and screenshot tests
  render real rows locally without touching the network.
- Added `test/ui_screenshots_test.dart`: writes **18 PNGs** to
  `build/ui_screenshots/` at 360×800 light English (Home, POS, Sales,
  Inventory, Rentals, People, Payroll, Settings, each Cash tab, Customers,
  one add-record form). CI uploads them as the `ui-screenshots` artifact.
- Added `tool/payload_drift_test.py`: real static drift check of every
  `TableSpec`/`FieldSpec` in `lib/data/schema.dart` against
  `supabase/fixtures/live_schema.sql`, with a printed per-table result. CI now
  runs it next to `tool/check_schema.py`.

### Translations
- English template lookup fixed (`uiTemplateSources[key] ?? key`), so raw
  keys such as `searchRecords` no longer render in English.
- Added `en` / `am` / `om` phrases for the new UI strings (Search records,
  Refresh, Export CSV, Export PDF, Add, Cash balance, Today’s sales, Low
  stock, Overdue, Rent due, Staff present, No records yet).
- Regenerated `lib/l10n/ui_text.dart` (163 phrases, 16 templates).

## Verified locally (real output)

```
$ ./tool/format.sh
Formatted 81 files (0 changed) in 7.01 seconds.

$ dart format --output=none --set-exit-if-changed lib test
Formatted 81 files (0 changed) in 7.06 seconds.   # exit 0

$ flutter analyze
No issues found! (ran in 26.6s)

$ flutter test
06:18 +285: All tests passed!

$ bash tool/check_placeholders.sh
Static placeholder check passed.

$ python3 tool/check_schema.py
PASS

$ python3 tool/payload_drift_test.py
checked 81 app tables/views against 81 live tables/views
PASS: every app table/view and field exists in the live snapshot

$ flutter test test/ui_screenshots_test.dart
SCREENSHOT | wrote 18 files to build/ui_screenshots
```

Measured layout on the main screens (light English, 360×800):

```
header 176.0 dp = 22.0%
green share: / 32.1% · /pos 29.6% · /sales 29.8% · /inventory 29.5%
             /cash 30.4% · /settings 35.8% · /reports 25.7% · /approvals 25.9%
```

## Not done in this branch (honest scope)

- Tablet/wide two-column card grid and side navigation are **not**
  implemented.
- Tab labels use the compact scrollable tab bar with the gold underline, but
  do not carry small icons yet.
- The gold Add action is the 48 dp circular action in the compact toolbar,
  not a Material `FloatingActionButton`.
- A skeleton loader is not added; lists still use the existing progress
  indicator, pull-to-refresh and lazy `ListView.builder`.
- The drift test is static (schema snapshot vs app spec). It does not insert
  payloads into a live/local Postgres database.
- Owner must open and merge the PR and create any tag/release. This branch
  does not create or push tags or PRs.

## How to test

1. `flutter pub get`
2. `./tool/format.sh` (local formatting)
3. `flutter analyze`
4. `flutter test`
5. `python3 tool/check_schema.py && python3 tool/payload_drift_test.py`
6. Open `build/ui_screenshots/` to inspect the generated screens.
