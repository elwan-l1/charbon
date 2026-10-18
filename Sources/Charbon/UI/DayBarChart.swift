import CharbonCore
import SwiftUI

/// One bar per day, split by project, with the hours the day asks for marked on it.
struct DayBarChart: View {
  let days: [DayReport]
  var height: CGFloat = 170
  var showsHours = true
  let select: (DayReport) -> Void

  var body: some View {
    let peak = peakMinutes
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .bottom, spacing: 8) {
        ForEach(days) { day in
          DayBarColumn(day: day, peak: peak, height: height, showsHours: showsHours) {
            select(day)
          }
        }
      }
      legend
    }
  }

  private var legend: some View {
    HStack(spacing: 18) {
      HStack(spacing: 6) {
        Rectangle().fill(Theme.ink).frame(width: 18, height: 3)
        Text("Hours expected").font(.note).foregroundStyle(Theme.muted)
      }
      HStack(spacing: 6) {
        Swatch(color: nil, size: 14)
        Text("Worked, not booked").font(.note).foregroundStyle(Theme.muted)
      }
      HStack(spacing: 6) {
        Rectangle().fill(Theme.warn).frame(width: 14, height: 3)
        Text("Needs a fix").font(.note).foregroundStyle(Theme.muted)
      }
      Text("Click a day to edit it").font(.note).foregroundStyle(Theme.faint)
    }
  }

  // The scale holds a full day even when the week is short.
  private var peakMinutes: Int {
    let tallest = days.map { max($0.worked + $0.credited, $0.target, $0.booked) }.max() ?? 0
    return max(tallest, 8 * 60) + 45
  }
}

private struct DayBarColumn: View {
  let day: DayReport
  let peak: Int
  let height: CGFloat
  let showsHours: Bool
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        bar
        label
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
    .help(help)
  }

  private var bar: some View {
    ZStack(alignment: .bottom) {
      Rectangle().fill(isHovering ? Theme.hairline.opacity(2) : Theme.hairline)
      if day.kind == .holiday || day.kind == .dayOff {
        Hatch(color: Theme.hairline).clipped()
      }
      VStack(spacing: 0) {
        Spacer(minLength: 0)
        if day.worked > day.booked {
          Hatch(color: Theme.muted)
            .frame(height: scale(day.worked - max(day.booked, 0)))
            .clipped()
            .background(Theme.ink.opacity(0.08))
        }
        ForEach(day.bookings.reversed()) { booking in
          Rectangle()
            .fill(ProjectPalette.color(for: booking.id))
            .frame(height: scale(booking.minutes))
        }
      }
      if day.credited > 0 {
        Rectangle().fill(Theme.good.opacity(0.6)).frame(height: scale(day.credited))
      }
      if day.contractTarget > 0 {
        Rectangle().fill(Theme.ink).frame(height: 2)
          .offset(y: -scale(day.target) + 1)
      }
    }
    .frame(height: height)
    .overlay(alignment: .top) {
      if day.isWorking {
        Rectangle().fill(Theme.ember).frame(height: 4)
      }
    }
    .clipped()
  }

  private var label: some View {
    VStack(spacing: 2) {
      Text(weekday)
        .font(.system(size: 12, weight: day.isToday ? .black : .bold))
        .foregroundStyle(day.isToday ? Theme.ember : Theme.muted)
      if showsHours {
        Text(day.done > 0 ? Format.hours(day.done) : "–")
          .font(.figure(12, weight: .semibold))
          .foregroundStyle(day.issue?.isBlocking == true ? Theme.warn : Theme.ink)
      }
    }
  }

  private var weekday: String {
    (day.date.map { Format.weekdayShort($0) } ?? "").uppercased()
  }

  private func scale(_ minutes: Int) -> CGFloat {
    height * CGFloat(max(minutes, 0)) / CGFloat(peak)
  }

  private var help: String {
    guard let date = day.date else {
      return day.id
    }
    return "\(Format.longDate(date)): \(Format.hours(day.done)) of \(Format.hours(day.target))"
  }
}
