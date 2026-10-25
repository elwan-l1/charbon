import CharbonCore
import SwiftUI

/// One month as a calendar, with the totals of every week and the share of every project.
struct MonthView: View {
  let model: AppModel

  var body: some View {
    TimelineView(.everyMinute) { context in
      MonthContent(model: model, now: context.date)
    }
  }
}

private struct MonthContent: View {
  let model: AppModel
  let now: Date

  var body: some View {
    let timesheet = model.timesheet
    let anchor = model.monthAnchor
    let report = timesheet.snapshot(.month, containing: anchor).map {
      model.report(for: $0, now: now)
    }
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        PeriodHeader(
          title: Format.monthName(anchor),
          subtitle: String(CharbonCalendar.calendar.component(.year, from: anchor)),
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
          MonthSummary(model: model, report: report)
          IssueList(
            report: report,
            defaultProject: model.settings.settings.defaultProject,
            isBusy: timesheet.isBusy,
            edit: model.edit,
            bookAll: { Task { _ = await timesheet.bookDays(report.unbookedDays) } }
          )
          MonthCalendar(model: model, report: report)
          ProjectShareList(report: report, title: "Projects this month")
        } else {
          Text("Loading the month…").foregroundStyle(Theme.muted).padding(.top, 40)
        }
      }
      .padding(28)
      .frame(maxWidth: 1000, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .task(id: TimesheetController.key(.month, anchor)) {
      await timesheet.show(.month, containing: anchor)
    }
  }
}

private struct MonthSummary: View {
  let model: AppModel
  let report: PeriodReport

  var body: some View {
    let done = report.worked + report.credited
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
      StatTile(
        title: "Worked",
        value: Format.hours(done),
        caption: "of \(Format.hours(report.target)) this month"
      )
      if report.targetSoFar > 0 {
        StatTile(
          title: "So far",
          value: Format.signed(report.difference),
          caption: "vs \(Format.hours(report.targetSoFar)) expected",
          tone: report.difference < 0 ? Theme.bad : Theme.good
        )
      }
      if let balance = report.balance {
        StatTile(
          title: "Overtime",
          value: Format.signed(balance),
          caption: report.startBalance.map { "started at \(Format.signed($0))" },
          tone: balance < 0 ? Theme.bad : Theme.good
        )
      }
      StatTile(
        title: "Days worked",
        value: "\(report.workedDays)",
        caption: report.workedDays > 0 ? "\(Format.hours(report.averagePerWorkedDay)) a day" : nil
      )
      if let rate = model.hourlyRate {
        StatTile(
          title: "Earned",
          value: Format.money(RateCalculator.earnings(minutes: report.worked, rate: rate)),
          caption: nil
        )
      }
      if let vacation = report.vacationBalance {
        StatTile(
          title: "Vacation left",
          value: Format.hours(vacation),
          caption: String(format: "about %.1f days", Double(vacation) / 504)
        )
      }
    }
  }
}

private struct MonthCalendar: View {
  let model: AppModel
  let report: PeriodReport

  var body: some View {
    VStack(spacing: 6) {
      HStack(spacing: 6) {
        Color.clear.frame(width: 70, height: 1)
        ForEach(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"], id: \.self) { name in
          Eyebrow(text: name).frame(maxWidth: .infinity)
        }
      }
      ForEach(report.weekTotals) { week in
        HStack(spacing: 6) {
          WeekTotalCell(week: week) {
            if let date = CharbonCalendar.date(fromKey: week.id) {
              model.openWeek(containing: date)
            }
          }
          ForEach(0..<7, id: \.self) { index in
            if let day = day(in: week, at: index) {
              MonthDayCell(day: day) { model.edit(day.id) }
            } else {
              Color.clear.frame(maxWidth: .infinity, minHeight: 78)
            }
          }
        }
      }
    }
    .panel()
  }

  private func day(in week: WeekTotal, at index: Int) -> DayReport? {
    report.days.first { day in
      guard let date = day.date else {
        return false
      }
      let weekday = (CharbonCalendar.calendar.component(.weekday, from: date) + 5) % 7
      return weekday == index
        && CharbonCalendar.dayKey(CharbonCalendar.weekStart(of: date)) == week.id
    }
  }
}

private struct WeekTotalCell: View {
  let week: WeekTotal
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 4) {
        Text("W\(week.number)").font(.system(size: 12, weight: .black))
        Text(Format.hours(week.worked)).font(.figure(12, weight: .semibold))
        BlockBar(
          fraction: week.target > 0 ? Double(week.worked) / Double(week.target) : 0,
          height: 6
        )
      }
      .padding(8)
      .frame(width: 70, height: 78, alignment: .topLeading)
      .background(Rectangle().fill(isHovering ? Theme.faint : Theme.hairline))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
    .help("Open week \(week.number)")
  }
}

private struct MonthDayCell: View {
  let day: DayReport
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      ZStack(alignment: .topLeading) {
        background
        VStack(alignment: .leading, spacing: 0) {
          HStack(alignment: .top) {
            Text(number).font(.system(size: 13, weight: .black))
              .foregroundStyle(day.isToday ? Theme.ember : Theme.ink)
            Spacer()
            if day.issue?.isBlocking == true {
              Swatch(color: Theme.warn, size: 10)
            } else if day.isLocked {
              Image(systemName: "lock").font(.system(size: 11)).foregroundStyle(Theme.faint)
            }
          }
          Spacer(minLength: 0)
          if day.done > 0 {
            Text(Format.hours(day.done)).font(.figure(15, weight: .heavy))
          } else if let name = day.day.dayOffName, day.kind != .work {
            Text(name).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Theme.muted)
              .lineLimit(1)
          }
          if day.target > 0 {
            BlockBar(
              fraction: Double(day.done) / Double(day.target),
              tone: day.done > day.target ? Theme.good : Theme.ink,
              height: 5
            )
            .padding(.top, 5)
          }
        }
        .padding(8)
      }
      .frame(maxWidth: .infinity, minHeight: 78, maxHeight: 78)
      .overlay(
        Rectangle().stroke(
          day.isToday ? Theme.ember : Theme.hairline, lineWidth: day.isToday ? 3 : 1.5)
      )
      .opacity(day.isFuture && day.done == 0 ? 0.6 : 1)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
  }

  private var number: String {
    day.date.map { Format.dayNumber($0) } ?? ""
  }

  @ViewBuilder
  private var background: some View {
    switch day.kind {
    case .work:
      (isHovering ? Theme.hairline : Theme.surface)
    case .weekend:
      Theme.hairline.opacity(0.6)
    case .holiday, .dayOff:
      ZStack {
        Theme.surface
        Hatch(color: Theme.hairline).clipped()
      }
    }
  }
}
