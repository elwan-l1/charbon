# L1 Agent Template

## Project

Mac menu bar app for timbrage.hefr.ch. Keep session alive. Clock in, clock out, book hours.

## Stack

Swift 6, AppKit, WebKit, SwiftUI for settings. macOS 14+. XcodeGen, swift-format, SwiftLint. SwiftPM for core tests.

## Map

- `Sources/CharbonCore`: pure logic. No UI. API client, models, stamp planner, hours planner, settings. `package` access, not `public`.
- `Sources/Charbon`: app. Menu bar, login window, session renew, cookies in Keychain, settings window.
- `Tests/CharbonTests`: core tests. `Tests/CharbonAppTests`: app tests.
- `docs/API.md`: how Timbrage server work. Read before network work.
- `project.yml`: source of Xcode project. Edit it, run `make generate`. Never edit `.xcodeproj` by hand.
- Check: `make verify`. Run app: `make run`.

## Architecture

- Login by web view. Session cookie HttpOnly. Only web view cookie store can read it. `WebKitTransport` copy cookies into URLSession.
- `SessionController` renew session alone: on start, on wake, on timer with jitter. No manual renew.
- `SessionRenewer` load renewal URL in hidden web view. Login form instead of timesheet = login needed.
- `CookieVault` keep cookies in Keychain across launches.
- `TimesheetController` load week after each renewal and on menu open. One write at a time. Stale data retry once.
- Server reject session: renew once a minute max. Open login window only if renewal say login needed. Valid session must never open it, else infinite loop.
- Week call need `no_age` param from `NoAGE` cookie. Without it server answer 404.
- Clock Out also book today hours on default project (`HoursPlanner`). `addRow` first if project not on week. Stamp stay if booking fail.
- Settings window: default project, optional hours per day, pay, menu bar format. Saved in `UserDefaults` by `SettingsStore`. New field must have default when old saved settings load.
- Pay: salary (month or year, 12 or 13 installments) or manual hourly rate. Rate = yearly salary / (weekly hours x 52). Never fetch salary from server. Currency CHF.
- Launch at login: toggle in Settings. `LaunchAtLogin` use `SMAppService.mainApp`. macOS hold the state, not `UserDefaults`. Off by default. Never register from dev build.
- Menu bar text next to icon (`MenuBarDisplay`, 7 formats). Timer in `StatusItemController` refresh it every 30 s.
- Menu show status, today, week (with money when rate known), booked hours. Items: Clock In or Clock Out, Settings.
- Never log or store raw server answers. Contain personal data.

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
