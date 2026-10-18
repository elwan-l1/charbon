import CharbonCore
import SwiftUI

/// Diagonal lines, for time that is not booked and days that are off.
struct Hatch: View {
  var color: Color = Theme.faint
  var spacing: CGFloat = 6

  var body: some View {
    Canvas { context, size in
      var path = Path()
      var offset = -size.height
      while offset < size.width {
        path.move(to: CGPoint(x: offset, y: size.height))
        path.addLine(to: CGPoint(x: offset + size.height, y: 0))
        offset += spacing
      }
      context.stroke(path, with: .color(color), lineWidth: 1.5)
    }
  }
}

/// A small square of colour for a project, or hatched for time that is not booked.
struct Swatch: View {
  let color: Color?
  var size: CGFloat = 16

  var body: some View {
    Group {
      if let color {
        Rectangle().fill(color)
      } else {
        Hatch(color: Theme.muted).clipped()
          .overlay(Rectangle().stroke(Theme.faint, lineWidth: 1))
      }
    }
    .frame(width: size, height: size)
  }
}

/// A flat bar that fills from the left, with the thick outline.
struct BlockBar: View {
  let fraction: Double
  var tone: Color = Theme.ink
  var height: CGFloat = 14
  /// Where a mark crosses the bar, between 0 and 1.
  var marker: Double?

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Rectangle().fill(Theme.hairline)
        Rectangle().fill(tone).frame(width: proxy.size.width * clamp(fraction))
        if let marker {
          Rectangle().fill(Theme.ink).frame(width: 2)
            .offset(x: proxy.size.width * clamp(marker) - 1)
        }
      }
    }
    .frame(height: height)
    .overlay(Rectangle().stroke(Theme.line, lineWidth: height < 8 ? 1.5 : Theme.stroke))
  }

  private func clamp(_ value: Double) -> Double {
    min(max(value, 0), 1)
  }
}

/// A figure with a small label above and a line of context below.
struct StatTile: View {
  let title: String
  let value: String
  var caption: String?
  var tone: Color = Theme.ink

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Eyebrow(text: title)
      Text(value)
        .font(.readout(26))
        .foregroundStyle(tone)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(caption ?? " ")
        .font(.note)
        .foregroundStyle(Theme.muted)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(padding: 16)
  }
}

/// The title of a week or a month with the buttons to move through time.
struct PeriodHeader: View {
  let title: String
  let subtitle: String
  let isCurrent: Bool
  let isLoading: Bool
  let previous: () -> Void
  let next: () -> Void
  let today: () -> Void

  var body: some View {
    HStack(alignment: .lastTextBaseline, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.title)
          .lineLimit(1)
        Text(subtitle)
          .font(.readingStrong)
          .foregroundStyle(Theme.muted)
      }
      if isLoading {
        ProgressView().controlSize(.small).padding(.bottom, 4)
      }
      Spacer()
      Button("Today", action: today)
        .buttonStyle(.block)
        .disabled(isCurrent)
      HStack(spacing: 6) {
        Button(action: previous) { Image(systemName: "chevron.left").frame(width: 14) }
          .help("Previous (⌘[)")
        Button(action: next) { Image(systemName: "chevron.right").frame(width: 14) }
          .help("Next (⌘])")
      }
      .buttonStyle(.block)
    }
  }
}

/// One project with its colour, hours and share of the time.
struct ShareRow: View {
  let name: String
  let minutes: Int
  let fraction: Double
  let color: Color?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        swatch
        Text(name).font(.readingStrong).lineLimit(1)
        Spacer(minLength: 12)
        Text(Format.hours(minutes)).font(.figure(14)).foregroundStyle(Theme.muted)
        Text(Format.percent(fraction)).font(.figure(14, weight: .heavy))
          .frame(width: 48, alignment: .trailing)
      }
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Rectangle().fill(Theme.hairline)
          if let color {
            Rectangle().fill(color).frame(width: proxy.size.width * min(fraction, 1))
          } else {
            Hatch().frame(width: proxy.size.width * min(fraction, 1)).clipped()
          }
        }
      }
      .frame(height: 9)
    }
  }

  private var swatch: some View {
    Swatch(color: color)
  }
}

/// The projects of a week or month with their share of the time, and what is not booked.
struct ProjectShareList: View {
  let report: PeriodReport
  var title = "Projects"

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Eyebrow(text: title)
        Spacer()
        Text("share of time worked").font(.note).foregroundStyle(Theme.muted)
      }
      if report.shares.isEmpty, report.unbookedMinutes == 0 {
        Text("Nothing worked yet. Clock in to start.").font(.reading).foregroundStyle(Theme.muted)
      }
      ForEach(report.shares) { share in
        ShareRow(
          name: share.title,
          minutes: share.minutes,
          fraction: share.fraction,
          color: ProjectPalette.color(for: share.id)
        )
      }
      if report.unbookedMinutes > 0 {
        ShareRow(
          name: "Not booked",
          minutes: report.unbookedMinutes,
          fraction: report.unbookedFraction,
          color: nil
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel()
  }
}

/// What the user should fix, one line per day, and the button to book what is late.
struct IssueList: View {
  let report: PeriodReport
  let defaultProject: ProjectChoice?
  let isBusy: Bool
  let edit: (String) -> Void
  let bookAll: () -> Void

  var body: some View {
    let blocking = report.issues.filter { $0.issue?.isBlocking == true }
    let unbooked = report.unbookedDays
    if !blocking.isEmpty || !unbooked.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        Label {
          Text("TO FIX").font(.system(size: 11.5, weight: .heavy)).tracking(1.2)
        } icon: {
          Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundStyle(Theme.warn)
        ForEach(blocking) { day in
          issueRow(day)
        }
        if !unbooked.isEmpty {
          bookRow(unbooked)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .panel(outline: Theme.warn)
    }
  }

  private func issueRow(_ day: DayReport) -> some View {
    HStack(spacing: 10) {
      Text(text(for: day)).font(.readingStrong)
      Spacer()
      Button("Fix") { edit(day.id) }.buttonStyle(.block)
    }
  }

  private func bookRow(_ days: [DayReport]) -> some View {
    let minutes = days.reduce(0) { total, day in
      if case .notBooked(let late)? = day.issue {
        return total + late
      }
      return total
    }
    return HStack(spacing: 10) {
      Rectangle().fill(Theme.warn).frame(width: 6, height: 6)
      Text(
        "\(Format.hours(minutes)) not booked on \(days.count) \(days.count == 1 ? "day" : "days")"
      )
      .font(.system(size: 13, weight: .semibold))
      Spacer()
      if let defaultProject {
        Button("Book on \(defaultProject.projectLabel)", action: bookAll)
          .buttonStyle(.block)
          .disabled(isBusy)
      } else {
        Text("Choose a default project in Settings to book it in one click.")
          .font(.note).foregroundStyle(Theme.muted)
      }
    }
  }

  private func text(for day: DayReport) -> String {
    let name = day.date.map { "\(Format.weekdayShort($0)) \(Format.dayMonth($0))" } ?? day.id
    switch day.issue {
    case .missingClockOut(let since):
      return "No clock out on \(name), in at \(since)"
    case .noStamps:
      return "Nothing stamped on \(name)"
    case .notBooked, nil:
      return name
    }
  }
}

/// A message above the content, for an error or a state the user can act on.
struct Notice: View {
  let text: String
  var tone: Color = Theme.bad

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(tone)
      Text(text).font(.readingStrong)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(padding: 14, outline: tone)
  }
}
