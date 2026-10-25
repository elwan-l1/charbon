import CharbonCore
import SwiftUI

/// One week: how much was worked, on which projects, and every day to open and fix.
struct WeekView: View {
  let model: AppModel

  var body: some View {
    TimelineView(.everyMinute) { context in
      WeekContent(model: model, now: context.date)
    }
  }
}

private struct WeekContent: View {
  let model: AppModel
  let now: Date

  var body: some View {
    let timesheet = model.timesheet
    let anchor = model.weekAnchor
    let report = timesheet.snapshot(.week, containing: anchor).map {
      model.report(for: $0, now: now)
    }
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        PeriodHeader(
          title: "Week \(CharbonCalendar.weekNumber(of: anchor))",
          subtitle: Format.weekRange(containing: anchor),
          isCurrent: model.isOnCurrentPeriod,
          isLoading: timesheet.loads > 0,
          previous: { model.step(-1) },
          next: { model.step(1) },
          today: model.goToCurrent
        )
        if let message = timesheet.message {
          Notice(text: message, problem: timesheet.problem)
        }
        if let report {
          summary(report)
          IssueList(
            report: report,
            defaultProject: model.settings.settings.defaultProject,
            isBusy: timesheet.isBusy,
            edit: model.edit,
            bookAll: { Task { _ = await timesheet.bookDays(report.unbookedDays) } }
          )
          WeekDayList(model: model, report: report)
        } else {
          Text("Loading the week…").foregroundStyle(Theme.muted).padding(.top, 40)
        }
      }
      .padding(28)
      .frame(maxWidth: 1000, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .task(id: TimesheetController.key(.week, anchor)) {
      await timesheet.show(.week, containing: anchor)
    }
  }

  @ViewBuilder
  private func summary(_ report: PeriodReport) -> some View {
    let done = report.worked + report.credited
    let rate = model.hourlyRate
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
      StatTile(
        title: "Worked",
        value: Format.hours(done),
        caption: Format.progress(done: done, target: report.target)
      )
      if let balance = report.balance {
        StatTile(
          title: "Overtime",
          value: Format.signed(balance),
          caption: "after finished days",
          tone: balance < 0 ? Theme.bad : Theme.good
        )
      }
      StatTile(
        title: "Booked",
        value: Format.hours(report.booked),
        caption: report.unbookedMinutes > 0
          ? "\(Format.hours(report.unbookedMinutes)) not booked" : "all booked"
      )
      if let rate {
        StatTile(
          title: "Earned",
          value: Format.money(RateCalculator.earnings(minutes: report.worked, rate: rate)),
          caption: nil
        )
      }
    }
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 14) {
        Eyebrow(text: "Per day")
        DayBarChart(days: report.days, height: 190) { model.edit($0.id) }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .panel()
      ProjectShareList(report: report)
        .frame(width: 340)
    }
  }
}

private struct WeekDayList: View {
  let model: AppModel
  let report: PeriodReport

  var body: some View {
    VStack(spacing: 8) {
      ForEach(report.days) { day in
        WeekDayRow(day: day) { model.edit(day.id) }
      }
    }
  }
}

private struct WeekDayRow: View {
  let day: DayReport
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Rectangle().fill(day.isToday ? Theme.ember : .clear).frame(
          width: 6, height: 26)
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.system(size: 13, weight: .heavy))
          if let tag {
            Text(tag).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
          }
        }
        .frame(width: 96, alignment: .leading)
        Text(periods).font(.figure(13, weight: .medium)).foregroundStyle(Theme.muted)
          .lineLimit(1)
        Spacer(minLength: 8)
        issueBadge
        Text(day.done > 0 ? Format.hours(day.done) : "–")
          .font(.figure(14, weight: .heavy)).frame(width: 56, alignment: .trailing)
        Text(day.target > 0 ? "/ \(Format.hours(day.target))" : "")
          .font(.figure(12)).foregroundStyle(Theme.muted).frame(width: 64, alignment: .leading)
        Text(difference).font(.figure(12, weight: .bold)).foregroundStyle(differenceColor)
          .frame(width: 56, alignment: .trailing)
        Image(systemName: day.isLocked ? "lock" : "pencil").foregroundStyle(Theme.faint)
          .frame(width: 20)
      }
      .padding(.vertical, 12)
      .padding(.leading, 10)
      .padding(.trailing, 16)
      .background(
        Rectangle().outlined(
          fill: isHovering ? Theme.paper : Theme.surface,
          line: isHovering ? Theme.line : Theme.hairline,
          width: isHovering ? Theme.stroke : 1.5)
      )
      .opacity(day.kind == .work || day.done > 0 ? 1 : 0.55)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
  }

  private var title: String {
    day.date.map { "\(Format.weekdayShort($0)) \(Format.dayNumber($0))" } ?? day.id
  }

  private var tag: String? {
    switch day.kind {
    case .work: nil
    case .weekend: day.day.dayOffName ?? "Weekend"
    case .holiday: day.day.dayOffName ?? "Holiday"
    case .dayOff: day.day.dayOffName ?? "Day off"
    }
  }

  private var periods: String {
    day.day.filledPeriods.map { period in
      let start = period.arrival.clockTime.map(\.description) ?? "?"
      let end = period.departure.clockTime.map(\.description) ?? (day.isToday ? "now" : "?")
      return "\(start)–\(end)"
    }
    .joined(separator: "   ")
  }

  @ViewBuilder
  private var issueBadge: some View {
    switch day.issue {
    case .missingClockOut:
      Text("NO CLOCK OUT").font(.system(size: 11.5, weight: .black)).tracking(0.6)
        .foregroundStyle(Theme.warn)
    case .noStamps:
      Text("NOTHING STAMPED").font(.system(size: 11.5, weight: .black)).tracking(0.6)
        .foregroundStyle(Theme.warn)
    case .notBooked:
      Text("NOT BOOKED").font(.system(size: 11.5, weight: .black)).tracking(0.6)
        .foregroundStyle(Theme.muted)
    case nil:
      EmptyView()
    }
  }

  private var difference: String {
    guard !day.isFuture, !day.isToday || !day.isWorking, day.contractTarget > 0 || day.done > 0
    else {
      return ""
    }
    return Format.signed(day.done - day.contractTarget)
  }

  private var differenceColor: Color {
    day.done - day.contractTarget < 0 ? Theme.bad : Theme.good
  }
}
