# Timbrage API

Notes from observing `https://timbrage.hefr.ch` (captured 2026-10-12). The write calls in sections 3 and 4 were captured live from a real day of clocking in and out.

## 1. Login

There is no password endpoint. Login is browser SSO (SAML 2.0 / Shibboleth):

1. Open `https://timbrage.hefr.ch/` without a session. It redirects to the Switch edu-ID discovery page (`wayf.switch.ch`).
2. The user picks **HES-SO** and signs in at `hes-so.login.eduid.ch` (password and MFA). The identity provider is `https://aai-logon.hes-so.ch/idp/shibboleth`.
3. The identity provider posts back to `/Shibboleth.sso/SAML2/POST`. The server sets a `_shibsession_*` cookie (**HttpOnly**) and redirects to `/#/user/week/timesheet`.

**API auth is cookies only.** No token, no CSRF, no custom headers. Every call is same-origin and carries the session cookies. The app therefore needs a web view for login, then keeps the cookies.

### Session expiry

- A session lasts **8 hours from when it was issued**. Check it after login with `GET /Shibboleth.sso/Session`: the line "Session Expiration (barring inactivity)" shows the minutes left (about 479 on a fresh session).
- The web app logs the user out after about 1 hour without mouse or keyboard activity. That is client-side only: the web app sends no keepalive request. Whether the server also has an idle timeout is **unknown**.
- The web app treats `401`, `403`, `404` and a failed request caused by a redirect to the login page as "logged out".
- Charbon should do the same. A `401`, `403`, `404`, a redirect to `wayf.switch.ch`, or HTML where JSON was expected all mean logged out.

### Renewing the session without a password

While the HES-SO login cookie is still valid, loading this URL in the web view issues a fresh 8-hour session with no prompt:

```
https://timbrage.hefr.ch/Shibboleth.sso/Login?entityID=https://aai-logon.hes-so.ch/idp/shibboleth&target=https://timbrage.hefr.ch/
```

- Tested twice on 2026-10-14. The expiry went from 460 back to 479 minutes, and the page returned to the timesheet in a few seconds.
- "Authentication Time" does not change: the login service reuses the original MFA login.
- The web view needs a persistent cookie store, so the login cookie survives app restarts.
- If the URL ends on a login form (`eduid.ch` or `wayf.switch.ch`), the login cookie has expired. Show the login window.
- **Unknown:** how long the HES-SO login cookie lasts. Check the renewal again after a few hours, a night and a weekend.

## 2. Conventions

- Base path: `/TimbrageWebApi/api/`. JSON.
- Dates in URLs: `yyyy-MM-dd`. Times: `"HH:mm"`. Durations: `"H:mm:ss"`.
- Requests use `""` for an empty time. Responses use `"00:00"` (see section 4).

## 3. Reading

| Method | Path | What it returns |
| --- | --- | --- |
| GET | `TimeSheet/Week?selected_date=YYYY-MM-DD&getAllActivitiesForEachProject=false&no_age=<NoAGE>` | The main payload: a whole week (below) |
| GET | `TimeSheet/GetProjects` | Every project the user can book on (large list) |
| POST | `User/MyProfile` | Profile and contract |
| GET | `TimeSheet/GetAbsenceProject?selected_date=…&is_month_range=false&no_age=…` | Absence projects |
| GET | `TimeSheet/GetEntryInfo?project_id=…&activity_id=…` | Info for one project entry |
| GET | `TimeSheet/Month` | Month view |

- `no_age` is the value of the readable `NoAGE` cookie. **Required:** without it, `TimeSheet/Week` answers `404` (JSON) even with a valid session.
- `MyProfile` contains personal data (AVS number, birth date). **Never log or store the raw response.**
- The web app does not poll. It re-fetches the week when the user navigates.

### Week response

```
Timesheet
  MondayDate, SundayDate
  Total      { Balance, Done, ToDo, Report }     e.g. ToDo "42:00:00"
  Periods    [{ DisplayOrder 0|1, Title }]       morning / afternoon
  Projects   [{ ProjectId, ActivityId, ProjectTitle, ActivityTitle, … }]
  Vacancy    { Balance, BalanceYear }
  Days[7]
    Date, IsHoliday, IsWeekend, IsDayOff, Stage
    Total        { Done, ToDo }                  e.g. ToDo "8:24:00"
    PeriodTimes  [{ Id, DisplayOrder, ArrivalTime, DepartureTime, Stage, RowVersion }]
    Projects     [{ ProjectId, ActivityId, Hours, Remark, Stage, RowVersion }]
  Contracts  [{ PercentageActivity, … }]
```

- `ArrivalTime` and `DepartureTime` are each `{ Id, Time, IsWarranty, RowVersion }`.
- `Stage` 1 means editable.
- A new, empty entry has `Id: 0` and `RowVersion: ""`.
- The server already gives the theoretical hours (`ToDo`: 8:24 a day, 42 h a week at 100%). The app does not need that as a setting. A setting can still override it.

## 4. Writing

### Clock in and out: `PUT TimeSheet/UpdatePeriod`

Send the whole period object for that day with `ArrivalTime.Time` and/or `DepartureTime.Time` set. The server answers with the saved period, carrying new `Id`s and `RowVersion`s.

```json
{"Id":0,"DisplayOrder":0,"PersonId":1,"Day":"2026-10-12T00:00:00",
 "ArrivalTime":{"Id":0,"Time":"07:50","IsWarranty":false,"RowVersion":""},
 "DepartureTime":{"Id":0,"Time":"","IsWarranty":false,"RowVersion":""},
 "Stage":1,"RowVersion":""}
```

- **Clock in:** set the arrival of the first period that has none. Period 0 is the morning, period 1 the afternoon.
- **Clock out:** send the same object again, with the `Id`s and `RowVersion`s from the last response and `DepartureTime.Time` set.
- **Edit a time:** same call, with the latest `RowVersion`s.
- **Clear a time:** send that time as `""`.
- **Delete a period:** send both times as `""`. The server removes it and returns `Id: 0`.
- The time is the client's local `HH:mm`. The server does not use its own clock.
- The web app also sends `error_arrival` and `error_departure` flags. They look like UI leftovers, but I haven't tested leaving them out.

### Book hours on a project: `PUT TimeSheet/UpdateHoursAttribution?the_modifier_id=<PersonId>`

```json
{"Day":"2026-10-12T00:00:00","PersonId":1,"ProjectId":1,"ActivityId":1,
 "Hours":"8:20","Remark":null,"Stage":1,"RowVersion":""}
```

The server does **not** work out project hours from the clock-in and clock-out times. The client books them. After a day, Charbon needs a step that books the worked time on the default project.

### Other write calls

These exist in the web app's code but I haven't captured them live. `AddEntry`, `RemoveEntry`, `UpdateEntry`, `AddProject`, `RemoveProject`, `PinOrUnpinProjectActivity`, `UpdatePeriodTime`, `RemovePeriodEntry`. Charbon should not call the `User/…Timesheet` calls that validate, archive or lock a timesheet.

## 5. Gotchas

- **`"00:00"` means empty in responses.** A period with an arrival and a departure of `"00:00"` is **open**, meaning the user is clocked in.
- **Never send an empty new period.** A new period with `Id: 0` and both times `""` creates an empty record. Only send a period when at least one time is set.
- **RowVersion chain.** Every save returns new `RowVersion`s, and the next save must send them back. Send updates for the same day and period one at a time. Different days can be sent quickly (about 10 calls in 10 seconds worked, at 35 to 70 ms each).
- Future days are accepted, not just today.

## 6. Error codes

| Code | Meaning |
| --- | --- |
| `50` | Custom timesheet error (`ErrorMessage`, `SolutionMessage`) |
| `400` | Bad request |
| `406` | Not acceptable (for example, vacation hours) |
| `426` | Stale data. Re-fetch the week and retry |
| `401`, `403`, `404` | Session gone |
