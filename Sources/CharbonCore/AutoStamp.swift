import Foundation

/// What happened to the Mac.
package enum AutoStampEvent: Sendable {
  /// It woke up, was unlocked, or Charbon started.
  case opened
  /// It went to sleep or was locked.
  case closed
}

/// One of the four moments of a working day that can be stamped by itself.
package enum AutoStampSlot: String, CaseIterable, Sendable {
  case morningStart
  case morningEnd
  case afternoonStart
  case afternoonEnd

  package var title: String {
    switch self {
    case .morningStart: "Morning start"
    case .morningEnd: "Morning end"
    case .afternoonStart: "Afternoon start"
    case .afternoonEnd: "Afternoon end"
    }
  }

  package var isClockIn: Bool {
    self == .morningStart || self == .afternoonStart
  }
}

/// The times of the day between which a slot may be stamped, both included.
package struct AutoStampWindow: Codable, Equatable, Sendable {
  package var start: ClockTime
  package var end: ClockTime

  package init(start: ClockTime, end: ClockTime) {
    self.start = start
    self.end = end
  }

  package func contains(_ time: ClockTime) -> Bool {
    start <= time && time <= end
  }
}

/// Clocks in when the Mac opens and out when it closes, inside windows the user sets.
package struct AutoStampSettings: Codable, Equatable, Sendable {
  package var isEnabled = false
  package var morningStart = AutoStampWindow(
    start: ClockTime(minutes: 6 * 60), end: ClockTime(minutes: 10 * 60))
  package var morningEnd = AutoStampWindow(
    start: ClockTime(minutes: 11 * 60 + 30), end: ClockTime(minutes: 13 * 60))
  package var afternoonStart = AutoStampWindow(
    start: ClockTime(minutes: 13 * 60), end: ClockTime(minutes: 15 * 60))
  package var afternoonEnd = AutoStampWindow(
    start: ClockTime(minutes: 16 * 60 + 30), end: ClockTime(minutes: 20 * 60))

  package init() {}

  package func window(of slot: AutoStampSlot) -> AutoStampWindow {
    switch slot {
    case .morningStart: morningStart
    case .morningEnd: morningEnd
    case .afternoonStart: afternoonStart
    case .afternoonEnd: afternoonEnd
    }
  }

  package mutating func setWindow(_ window: AutoStampWindow, of slot: AutoStampSlot) {
    switch slot {
    case .morningStart: morningStart = window
    case .morningEnd: morningEnd = window
    case .afternoonStart: afternoonStart = window
    case .afternoonEnd: afternoonEnd = window
    }
  }

  /// The slot to stamp when `event` happens at `date`, or `nil` outside the windows, on a weekend
  /// or when it is off.
  package func slot(for event: AutoStampEvent, at date: Date) -> AutoStampSlot? {
    guard isEnabled, !CharbonCalendar.calendar.isDateInWeekend(date) else {
      return nil
    }
    let time = ClockTime(date: date, calendar: CharbonCalendar.calendar)
    return AutoStampSlot.allCases.first {
      $0.isClockIn == (event == .opened) && window(of: $0).contains(time)
    }
  }
}
