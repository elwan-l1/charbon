import CharbonCore
import SwiftUI

struct PeriodDraft: Identifiable {
  let id: Int
  var arrival: String
  var departure: String
}

struct HoursDraft: Identifiable {
  let project: ProjectChoice
  var text: String
  /// What the server holds, to tell what changed.
  let original: Int

  var id: String { project.id }
}

/// A box of the editor, so that Enter can move from one to the next.
enum EditorField: Hashable {
  case arrival(Int)
  case departure(Int)
  case hours(String)
}

/// What the user typed for one day, and what it adds up to.
@MainActor
struct DayDraft {
  var periods: [PeriodDraft]
  var hours: [HoursDraft]

  init(day: WeekDay?, rows: [WeekProject]) {
    var periods = (day?.periods ?? []).sorted { $0.displayOrder < $1.displayOrder }.map {
      PeriodDraft(
        id: $0.displayOrder,
        arrival: $0.arrival.clockTime.map(\.description) ?? "",
        departure: $0.departure.clockTime.map(\.description) ?? ""
      )
    }
    while periods.count < 2 {
      periods.append(
        PeriodDraft(id: (periods.map(\.id).max() ?? -1) + 1, arrival: "", departure: ""))
    }
    self.periods = periods
    hours = rows.map { row in
      let choice = ProjectChoice(
        projectId: row.projectId,
        activityId: row.activityId,
        projectLabel: row.projectTitle,
        activityLabel: row.activityTitle
      )
      let minutes = day?.projects.first { choice.matches($0) }?.duration?.minutes ?? 0
      return HoursDraft(
        project: choice,
        text: minutes > 0 ? Format.hours(minutes) : "",
        original: minutes
      )
    }
  }

  // MARK: Totals

  var workedMinutes: Int {
    periods.reduce(0) { $0 + minutes(of: $1) }
  }

  var bookedMinutes: Int {
    hours.reduce(0) { $0 + (TimeInput.duration($1.text).valueOrNil ?? 0) }
  }

  /// Minutes between the two times, or 0 while one is missing or they are in the wrong order.
  func minutes(of period: PeriodDraft) -> Int {
    guard let start = TimeInput.clock(period.arrival).valueOrNil,
      let end = TimeInput.clock(period.departure).valueOrNil, end > start
    else {
      return 0
    }
    return end.minutes - start.minutes
  }

  /// The time worked that the other projects do not hold.
  func restMinutes(for draft: HoursDraft) -> Int {
    let others = hours.filter { $0.id != draft.id }
      .reduce(0) { $0 + (TimeInput.duration($1.text).valueOrNil ?? 0) }
    return workedMinutes - others
  }

  // MARK: Fields

  /// The boxes in the order Enter walks through them.
  var fieldOrder: [EditorField] {
    periods.flatMap { [EditorField.arrival($0.id), .departure($0.id)] }
      + hours.map { EditorField.hours($0.id) }
  }

  /// Rewrites what was typed in the way it is stored: `750` becomes `07:50`.
  mutating func normalize(_ field: EditorField) {
    switch field {
    case .arrival(let id):
      if let index = periods.firstIndex(where: { $0.id == id }) {
        periods[index].arrival = Self.clockText(periods[index].arrival)
      }
    case .departure(let id):
      if let index = periods.firstIndex(where: { $0.id == id }) {
        periods[index].departure = Self.clockText(periods[index].departure)
      }
    case .hours(let id):
      if let index = hours.firstIndex(where: { $0.id == id }) {
        hours[index].text = Self.durationText(hours[index].text)
      }
    }
  }

  private static func clockText(_ text: String) -> String {
    switch TimeInput.clock(text) {
    case .value(let time): time.description
    case .empty: ""
    case .invalid: text
    }
  }

  private static func durationText(_ text: String) -> String {
    switch TimeInput.duration(text) {
    case .value(let minutes): minutes > 0 ? Format.hours(minutes) : ""
    case .empty: ""
    case .invalid: text
    }
  }

  // MARK: Saving

  /// What to save, or why the fields cannot be read.
  func makeEdit(dayKey: String) throws -> DayEdit {
    var edits: [PeriodEdit] = []
    for period in periods {
      let arrival = TimeInput.clock(period.arrival)
      let departure = TimeInput.clock(period.departure)
      guard arrival != .invalid, departure != .invalid else {
        throw CharbonError.invalidEdit("Write times like 08:15, or just 815.")
      }
      edits.append(
        PeriodEdit(
          displayOrder: period.id, arrival: arrival.valueOrNil, departure: departure.valueOrNil))
    }
    var changes: [HoursEdit] = []
    for draft in hours {
      let result = TimeInput.duration(draft.text)
      guard result != .invalid else {
        throw CharbonError.invalidEdit("Write hours like 8:20.")
      }
      let minutes = result.valueOrNil ?? 0
      if minutes != draft.original {
        changes.append(HoursEdit(project: draft.project, minutes: minutes))
      }
    }
    return DayEdit(dayKey: dayKey, periods: edits, hours: changes)
  }
}

/// A small box for a time or a duration.
///
/// Enter commits it and moves to the next box.
struct TimeField: View {
  @Binding var text: String
  let placeholder: String
  let isValid: Bool
  let field: EditorField
  var focus: FocusState<EditorField?>.Binding
  let submit: () -> Void

  var body: some View {
    TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.faint))
      .focused(focus, equals: field)
      .onSubmit(submit)
      .textFieldStyle(.plain)
      .font(.figure(15, weight: .semibold))
      .multilineTextAlignment(.center)
      .frame(width: 70)
      .padding(.vertical, 8)
      .background(
        Rectangle().outlined(
          fill: focus.wrappedValue == field ? Theme.paper : Theme.surface,
          line: isValid ? Theme.line : Theme.bad,
          width: focus.wrappedValue == field ? 3 : Theme.stroke
        )
      )
      .accessibilityLabel(placeholder)
  }
}
