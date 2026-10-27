# Changelog

All notable changes to Charbon are documented here.

## [Unreleased]

## [0.3.0] - 2026-10-27

### Added

- Automatic login. Save your edu-ID email, password and authenticator key in Settings, and Charbon logs in again by itself when the session is gone. They stay in the Keychain of your Mac.
- Check for updates from the menu bar or the app menu. Charbon never checks or downloads by itself.
- Errors show a code and one sentence. After a few failed tries, a link opens a mail to the maintainer with the details filled in.

### Changed

- The session is renewed every 90 minutes, give or take 20, and a failed renewal tries again after 15 seconds.
- The Today screen no longer shows the day timeline, and the week bars fill from the bottom.

## [0.2.0] - 2026-10-18

### Added

- A real app window with a Dock icon, next to the menu bar item. Open it from the Dock, the menu bar or ⌘0.
- Today screen: hours worked, progress through the day, when the day ends, overtime, booked hours and the week at a glance.
- Week screen: hours per day split by project, share of time per project, overtime and every day to edit.
- Month screen: a calendar with the hours of each day and week, share of time per project, days worked, hours left to do and vacation left.
- Edit the clock in and out times of any day and book hours on any project of the week.
- Time boxes understand quick typing: `750` is 07:50 and `112` is 11:20. 
- Warnings for days without a clock out or without stamps and one click to book all unbooked days on the default project.
- A welcome tour on first launch: appearance, hours, pay, menu bar and project. It can be skipped and replayed from Settings.
- Light and dark appearance or follow the system preference.
- Option to hide the item in the menu bar.

### Changed

- Settings are inside the main window and the menu bar opens them there.
- New look: flat boxes and buttons with square corners and a thick outline, stronger contrast and bigger text. The sidebar has no solid fill.
- The menu bar text shows all day with the format you chose also before you clock in, instead of only after you worked.
- The app has a main menu now. Closing the window keeps the menu bar item and the session alive.

## [0.1.1] - 2026-10-18

### Changed

- The disk image opens with a custom installer window using same style as the rest of the app.

## [0.1.0] - 2026-10-18

### Added

- Log in to Timbrage through the HES-SO login and keep the session alive with automatic renewals.
- Show today's status in the menu: when you clocked in, hours worked today and this week.
- Clock in and out from the menu.
- Book the worked hours on a default project when you clock out.
- Show the worked time, the share of the day or earnings next to the menu bar icon.
- Settings for the default project, the hours per day, the salary or hourly rate and the menu bar format.
- Launch Charbon at login from Settings.
