import CharbonCore
import SwiftUI

/// The first screen: the state of today, the button to clock in or out and the week at a glance.
struct TodayView: View {
  let model: AppModel

  var body: some View {
    TimelineView(.everyMinute) { context in
      TodayContent(model: model, now: context.date)
    }
  }
}

private struct TodayContent: View {
  let model: AppModel
  let now: Date

  var body: some View {
    let timesheet = model.timesheet
    let week = timesheet.snapshot.map { model.report(for: $0, now: now) }
    let month = timesheet.snapshot(.month, containing: now).map { model.report(for: $0, now: now) }
    let today = week?.days.first(where: \.isToday)
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        header
        if let message = timesheet.message {
          Notice(text: message, problem: timesheet.problem)
        }
        TodayHero(model: model, today: today, now: now)
        tiles(week: week, month: month, today: today)
        if let week {
          VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "This week")
            DayBarChart(days: week.days, height: 96) { model.edit($0.id) }
          }
          .panel()
        }
        if let issues = month ?? week {
          IssueList(
            report: issues,
            defaultProject: model.settings.settings.defaultProject,
            isBusy: timesheet.isBusy,
            edit: model.edit,
            bookAll: { Task { _ = await timesheet.bookDays(issues.unbookedDays) } }
          )
        }
      }
      .padding(28)
      .frame(maxWidth: 940, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .task { await timesheet.refresh(force: false) }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text(Format.weekdayLong(now)).font(.title)
        Text(Format.fullDate(now)).font(.readingStrong).foregroundStyle(Theme.muted)
      }
      Spacer()
      if model.timesheet.loads > 0 {
        ProgressView().controlSize(.small)
      }
    }
  }

  private func tiles(week: PeriodReport?, month: PeriodReport?, today: DayReport?) -> some View {
    let rate = model.hourlyRate
    return LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
      if let week {
        let done = week.worked + week.credited
        StatTile(
          title: "This week",
          value: Format.hours(done),
          caption: Format.progress(done: done, target: week.target)
        )
      }
      if let balance = month?.balance {
        StatTile(
          title: "Overtime",
          value: Format.signed(balance),
          caption: "after finished days",
          tone: balance < 0 ? Theme.bad : Theme.good
        )
      }
      if let today {
        StatTile(
          title: "Booked today",
          value: Format.hours(today.booked),
          caption: today.worked > today.booked
            ? "\(Format.hours(today.worked - today.booked)) not booked" : "all booked"
        )
        if let rate {
          StatTile(
            title: "Earned today",
            value: Format.money(RateCalculator.earnings(minutes: today.worked, rate: rate)),
            caption: week.map {
              "week: " + Format.money(RateCalculator.earnings(minutes: $0.worked, rate: rate))
            }
          )
        }
      }
      if let vacation = month?.vacationBalance {
        StatTile(
          title: "Vacation left",
          value: Format.hours(vacation),
          caption: String(format: "about %.1f days", Double(vacation) / 504)
        )
      }
    }
  }
}

/// Today in one box: hours worked, how far the day is, and the button.
private struct TodayHero: View {
  let model: AppModel
  let today: DayReport?
  let now: Date

  var body: some View {
    let timesheet = model.timesheet
    HStack(alignment: .center, spacing: 28) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
          Swatch(color: today?.isWorking == true ? Theme.ember : Theme.faint, size: 11)
          Eyebrow(text: status, color: today?.isWorking == true ? Theme.ember : Theme.muted)
        }
        Text(today.map { Format.hours($0.worked) } ?? "–:––")
          .font(.readout(76))
          .minimumScaleFactor(0.5)
          .lineLimit(1)
        Text(detail).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
        BlockBar(fraction: fraction, tone: fraction > 1 ? Theme.good : Theme.ink, height: 16)
          .frame(maxWidth: 420)
      }
      Spacer(minLength: 0)
      VStack(alignment: .trailing, spacing: 12) {
        Button {
          Task {
            if today?.isWorking == true {
              await timesheet.clockOut()
            } else {
              await timesheet.clockIn()
            }
          }
        } label: {
          Text(today?.isWorking == true ? "Clock out" : "Clock in")
            .frame(minWidth: 150)
        }
        .buttonStyle(.blockHero)
        .disabled(today == nil || timesheet.isBusy || today?.isLocked == true)
        if timesheet.isBusy {
          ProgressView().controlSize(.small)
        } else if let finish {
          Text(finish).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.muted)
        }
      }
    }
    .panel(padding: 26)
  }

  private var fraction: Double {
    guard let today, today.target > 0 else {
      return 0
    }
    return Double(today.worked) / Double(today.target)
  }

  private var status: String {
    guard let today else {
      return "Loading"
    }
    if today.isWorking, let since = today.day.openPeriod?.arrival.clockTime {
      return "Working since \(since)"
    }
    if let last = today.day.filledPeriods.compactMap(\.departure.clockTime).max() {
      return "Clocked out at \(last)"
    }
    return "Not clocked in"
  }

  private var detail: String {
    guard let today else {
      return " "
    }
    guard today.target > 0 else {
      return "No hours expected today"
    }
    return "of \(Format.hours(today.target)) · \(Format.percent(fraction))"
  }

  // When the day is done if the user keeps working, or how much is over.
  private var finish: String? {
    guard let today, today.target > 0 else {
      return nil
    }
    let remaining = today.target - today.worked
    if remaining <= 0 {
      return today.worked > today.target ? "\(Format.hours(-remaining)) over" : "Day complete"
    }
    guard today.isWorking else {
      return "\(Format.hours(remaining)) left"
    }
    let end = ClockTime(minutes: ClockTime(date: now).minutes + remaining)
    return "Done at \(end) · \(Format.hours(remaining)) left"
  }
}
