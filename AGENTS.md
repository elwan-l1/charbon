# L1 Agent Template

## Project

Mac menu bar app for timbrage.hefr.ch. Keep session alive. Clock in, clock out, book hours.

## Stack

Swift 6, AppKit, WebKit, SwiftUI for settings. macOS 14+. XcodeGen, swift-format, SwiftLint. SwiftPM for core tests.

## Map

- `Sources/CharbonCore`: pure logic. No UI. API client, models, stamp planner, hours planner, settings. `package` access, not `public`.
- `Sources/Charbon`: app. Main window, menu bar, login window, session renew, cookies in Keychain, settings window.
- `Sources/Charbon/UI`: SwiftUI of the main window. `Theme` holds colours and shapes. `AppModel` holds screen and dates.
- `Tests/CharbonTests`: core tests. `Tests/CharbonAppTests`: app tests.
- `docs/API.md`: how Timbrage server work. Read before network work.
- `project.yml`: source of Xcode project. Edit it, run `make generate`. Never edit `.xcodeproj` by hand.
- Check: `make verify`. Run app: `make run`.

## Architecture

- Login by web view. Session cookie HttpOnly. Only web view cookie store can read it. `WebKitTransport` copy cookies into URLSession.
- Session flow. One controller, `SessionController`. No separate manual and automatic session. It starts a renewal on launch, on wake, and every 90 min ±20. A network failure retries after 15 s. A renewal is `SessionRenewer` loading `CharbonEnvironment.renewalURL` in a hidden web view. That URL is the Shibboleth login URL with the HES-SO identity provider as `entityID`: it skips the institution picker and goes straight to edu-ID. Three outcomes, in order:
  1. Extend. edu-ID still remembers the user (its login cookie, kept by the web view and `CookieVault`, is valid). It sends the web view back to Timbrage with a new session that lasts 8 h. No prompt. `SessionProbe` reads `/Shibboleth.sso/Session` to confirm and get the minutes left. State `signedIn`.
  2. Kicked to login. edu-ID forgot the user: the URL ends on an edu-ID login form, not on Timbrage. If a login is saved (`CredentialVault`, Keychain, set in Settings or onboarding), `LoginAutofill` fills the pages in the same hidden web view: email, "Use password", password, then the TOTP code if asked (`TOTP`, core). Then it is outcome 1.
  3. Cannot get in. No saved login: state `loginRequired`, not an error. Saved login but the autofill failed: `loginRequired` plus a `CharbonProblem` 2xxx. Now the user logs in by hand in `LoginWindowController` (visible web view, autofill runs there too). It opens only when an API call needs it, never on its own.
  The renewal waits 20 s for Timbrage. Each page the autofill fills restarts the wait, and a TOTP code that was just used adds up to 30 s.
- `LoginAutofill` limits: max 2 tries per page, never the same TOTP code twice, off after 2 failed runs that sent the password. A wrong password must not lock the account. Settings Save resets it. Log Out forgets the saved login.
- Errors: `CharbonProblem` (core) gives a code and one sentence, never a stack. 1xxx network and session, 2xxx automatic login, 3xxx Keychain, 4xxx Timbrage API, 5000 unexpected. The session keeps `problem` and `failures`. After 3 failures in a row the window and menu offer a mail to the maintainer.
- Logs: `SessionLog` keeps what happened to the session (renewals and why, retries, autofill steps, logins, logouts, errors with code) in `Application Support/Charbon/session-log.json`, last 500. A screen under Settings in the sidebar (`LogsView`) shows it, with Copy and Clear. Never log a password, a code or a cookie.
- `CookieVault` keep cookies in Keychain across launches.
- `TimesheetController` caches weeks and months by first day. Loads today after each renewal and on menu open, other periods when a screen asks. One write at a time. Stale data retry once. After a write it reads every touched week and month again.
- Main window is a regular app window with Dock icon. Closing it never quits: menu bar item keeps session alive. Screens: Today, Week, Month. Day editor sheet edits stamps and booked hours, through `DayEditPlanner` and `HoursPlanner`.
- `PeriodReport` and `DayReport` (core) work out totals, project shares, overtime and issues. A past day with an open period counts as zero worked. Vacation and absence hours count as done.
- Look: flat, thick ink outline, square corners, no radius, no shadows, like the icon. Plain rectangles for every box, button and field. Muted text keeps 4.5:1 contrast, no text under 12 pt. Light and dark both. Setting `appearance` can force one.
- Server reject session: renew once a minute max. Open login window only if renewal say login needed. Valid session must never open it, else infinite loop.
- Week call need `no_age` param from `NoAGE` cookie. Without it server answer 404.
- Clock Out also book today hours on default project (`HoursPlanner`). `addRow` first if project not on week. Stamp stay if booking fail.
- Settings are a screen of the main window, no separate window. Appearance, hours per day, pay (off, salary, hourly rate), menu bar item and format, default project, launch at login. Saved in `UserDefaults` by `SettingsStore`. New field must have default when old saved settings load.
- Onboarding (`OnboardingView`) shows while `hasCompletedOnboarding` is false: welcome, login, appearance, hours, pay, menu bar, project and startup, summary. Every step can be skipped. Settings can replay it. Editors in `SettingsEditors.swift` and `MenuBarEditor.swift` are shared by Settings and onboarding.
- Time boxes read `750` as 07:50 and `112` as 11:20 (`TimeInput`). Enter writes the full time and moves to the next box.
- Pay: salary (month or year, 12 or 13 installments) or manual hourly rate. Rate = yearly salary / (weekly hours x 52). Never fetch salary from server. Currency CHF.
- Launch at login: toggle in Settings. `LaunchAtLogin` use `SMAppService.mainApp`. macOS hold the state, not `UserDefaults`. Off by default. Never register from dev build.
- Menu bar text next to icon (`MenuBarDisplay`, 7 formats), always shown unless icon only. Timer in `StatusItemController` refresh it every 30 s.
- Menu show status, today, week (with money when rate known), booked hours. Items: Open Charbon, Clock In or Clock Out, Settings (opens the settings screen in the main window). Setting `showsMenuBarItem` hides the item.
- Release: push tag `vX.Y.Z` from `main` start `.github/workflows/release.yml`. Preflight, sign with Developer ID, notarize, DMG, GitHub release. Scripts in `Scripts/release/`. The release also holds a signed `appcast.xml`.
- Updates: Sparkle 2.10.0. Menu item "Check for Updates…" in the menu bar menu and the app menu. Never checks or downloads on its own: `SUEnableAutomaticChecks`, `SUAutomaticallyUpdate`, `SUAllowsAutomaticUpdates` are off in `project.yml`. Feed is `releases/latest/download/appcast.xml`, signed (`SURequireSignedFeed`). `generate-appcast.sh` makes it in the release workflow. Signing key: Keychain account `ch.codevs.charbon` (Sparkle `generate_keys`), public half in `project.yml` and `common.sh`. Before the first release with an appcast, the check ends in an error: the feed does not exist yet.
- Secrets live in GitHub environment `release-signing`: `SIGNING_CERT_P12`, `SIGNING_CERT_PASSWORD`, `NOTARY_API_KEY_P8`, `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`, `SPARKLE_EDDSA_PRIVATE_KEY`.
- Disk image window: `dmgbuild` (pinned, in `.build/dmgbuild`) with `Scripts/release/dmg-settings.py`. Background art drawn at build time by `Scripts/make-dmg-background.swift`, no committed images. Style like app icon: flat, hard edges, no rounding, no texture. Background must stay light: Finder draws icon names black on any window with a background picture, even in dark mode. Icon positions in script and settings must match. 2x picture must stay 144 dpi: join with `tiffutil -cat`, never `-cathidpicheck`.
- `make release-dry-run` run whole pipeline local: ad hoc sign, no notarize. `make ci` run it.

## Engineering

- Repo conventions first. Simple code. Focused patch.
- Guard clauses over nested conditions. Arrow functions in JS/TS.
- Strict TypeScript. No `any` without narrow, justified escape hatch.
- Comments rare. Inline comments lowercase. Public APIs use standard doc comments
  only when useful.
- No compatibility shims, aliases, dual paths, or deprecation layers. Change
  internal callers directly unless user requests migration period.
- No speculative safeguards, fallback, retry, validation, or abstraction. Require
  concrete boundary, failure, or invariant.
- No unrelated cleanup, refactor, lint fix, or dependency upgrade.

## Work

- All task file operations and command working directories stay inside repo.
  System executables and runtime dependencies allowed only for project commands.
- Destructive command only when required. Resolve every target inside repo.
  Never target broad path, unresolved variable, home, filesystem root, or repo
  root.
- Never use `sudo`. Never install or update global/system packages. No Homebrew or
  global `npm`/`pnpm`.
- Git read-only by default. Allowed: `git status`, `git diff`, `git log`,
  `git show`, `git blame`, `git grep`, `git ls-files`, `git rev-parse`.
  `git stash`, `git commit`, and `git push` are allowed only when the user
  explicitly requests the exact operation. `git add` is allowed only to stage
  the files included in an explicitly requested commit. All other Git actions
  forbidden.

## Communication

Default response style: full Caveman. Active every response until user opts out.
Technical substance stays; conversational overhead dies. Style never reduces
analysis, implementation, or verification.

- Drop unnecessary articles, filler, pleasantries, hedging. Fragments OK. Short
  common words. Each fact once.
- Preferred shape: subject, action, reason. Next step.
- Preserve exact technical terms, code, commands, paths, API/function names,
  commit types, and quoted errors. Translate only when requested.
- Always communicate with the user in English, regardless of the language they
  use. Translate content only when explicitly requested.
- Established acronyms OK: API, DB, HTTP. Never invent abbreviations such as
  `cfg`, `impl`, `req`, `res`, or `fn`. No decorative arrows.
- No self-reference, style announcement, normal-answer-plus-recap, emoji,
  decorative table, repetitive tool narration, or long raw error dump. Quote
  shortest decisive error line unless full output requested.
- Security warning, irreversible confirmation, ambiguity-prone ordered steps, or
  confused/repeating user: use clear normal prose for that part. Resume Caveman
  afterward.
- Code, commit messages, PR descriptions, and repo artifacts use normal
  conventional style.
- User says `stop caveman`, `normal mode`, `do not use caveman`, or equivalent:
  write normal prose for rest of task/session. Resume only after explicit user
  enablement. Latest explicit style preference wins.

## Search

- Use `rg` for search. Use `rg --files` for files.
- Search local path first. Expand only when needed.
- Combine terms in one regex. Read matches and nearby lines.
- No `grep`, `find`, or broad scans unless `rg` fails.
- Example: `rg -n "symbol|error|behavior" src/`

## Verification

- Never add unit/integration tests, snapshots, fixtures, or test-only helpers
  unless user explicitly requests them.
- Existing automated tests may run. They never replace real behavior validation.
- Code review, lint, type-check, build success do not prove feature works. Exercise
  affected behavior realistically before claiming success.
- UI: when useful, inspect browser before edit for baseline. Inspect after edit.
  Verify requested elements, states, interactions, relevant viewports, intended
  visual change, regressions.
- Docker/infrastructure/config/dependency/service: validate rendered config and
  runtime paths. As applicable check startup, health, connectivity, ordering,
  persistence, changed behavior.
- Blocked validation: never claim success. State verified work, unverified work,
  exact blocker.
