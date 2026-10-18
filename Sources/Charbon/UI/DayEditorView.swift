import CharbonCore
import SwiftUI

/// Edits the stamps and the booked hours of one day.
struct DayEditorView: View {
  let model: AppModel
  let dayKey: String

  @Environment(\.dismiss) private var dismiss
  @State private var draft: DayDraft
  @State private var error: String?
  @State private var isSaving = false
  @State private var isChoosingProject = false
  @FocusState private var focus: EditorField?

  private let report: DayReport?
  private let originalPeriods: [PeriodEdit]

  init(model: AppModel, dayKey: String) {
    self.model = model
    self.dayKey = dayKey
    let date = CharbonCalendar.date(fromKey: dayKey) ?? Date()
    let snapshot =
      model.timesheet.snapshot(.week, containing: date)
      ?? model.timesheet.snapshot(.month, containing: date)
    let day = snapshot?.timesheet.days.first { $0.key == dayKey }
    report = day.map {
      DayReport(
        day: $0,
        todayKey: CharbonCalendar.dayKey(Date()),
        now: ClockTime(date: Date()),
        dailyMinutes: model.dailyMinutes
      )
    }
    originalPeriods = day?.periods.map(PeriodEdit.init) ?? []
    _draft = State(initialValue: DayDraft(day: day, rows: snapshot?.timesheet.projects ?? []))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      header
      if report?.isLocked == true {
        Notice(text: "This day is locked in Timbrage.", tone: Theme.warn)
      }
      if case .missingClockOut(let since)? = report?.issue {
        Notice(
          text: "No clock out after \(since). Type the time you left in the first empty “out” box.",
          tone: Theme.warn)
      }
      stampsSection
      projectsSection
      if let error {
        Notice(text: error)
      }
      footer
    }
    .padding(28)
    .frame(width: 580)
    .background(Theme.paper)
    .onChange(of: focus) { old, _ in
      if let old {
        draft.normalize(old)
      }
    }
    .sheet(isPresented: $isChoosingProject) {
      ProjectPickerView(model: model.settings, selectedID: nil) { choice in
        guard !draft.hours.contains(where: { $0.id == choice.id }) else {
          return
        }
        draft.hours.append(HoursDraft(project: choice, text: "", original: 0))
      }
    }
  }

  private var isLocked: Bool {
    report?.isLocked == true || report == nil
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(CharbonCalendar.date(fromKey: dayKey).map { Format.weekdayLong($0) } ?? dayKey)
        .font(.title)
      Text(CharbonCalendar.date(fromKey: dayKey).map { Format.fullDate($0) } ?? "")
        .font(.readingStrong).foregroundStyle(Theme.muted)
    }
  }

  // MARK: Stamps

  private var stampsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        SectionTitle(title: "Clock in and out", help: "Type 750 and press Enter for 07:50.")
        Spacer()
        Text("\(Format.hours(draft.workedMinutes)) worked").font(.figure(14, weight: .heavy))
        if let target = report?.target, target > 0 {
          Text("of \(Format.hours(target))").font(.figure(14)).foregroundStyle(Theme.muted)
        }
      }
      ForEach($draft.periods) { $period in
        HStack(spacing: 10) {
          Text("Period \(period.id + 1)").font(.note)
            .foregroundStyle(Theme.muted).frame(width: 68, alignment: .leading)
          timeField($period.arrival, "in", .arrival(period.id))
          Text("→").foregroundStyle(Theme.muted)
          timeField($period.departure, "out", .departure(period.id))
          Text(length(of: period)).font(.figure(13)).foregroundStyle(Theme.muted)
          Spacer()
          Button("Clear") {
            period.arrival = ""
            period.departure = ""
          }
          .buttonStyle(.blockQuiet)
          .disabled(period.arrival.isEmpty && period.departure.isEmpty)
        }
      }
      Button("Add a period") {
        let next = (draft.periods.map(\.id).max() ?? -1) + 1
        draft.periods.append(PeriodDraft(id: next, arrival: "", departure: ""))
      }
      .buttonStyle(.block)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .disabled(isLocked)
    .panel()
  }

  // MARK: Projects

  private var projectsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        SectionTitle(title: "Hours booked")
        Spacer()
        Text("\(Format.hours(draft.bookedMinutes)) of \(Format.hours(draft.workedMinutes))")
          .font(.figure(14, weight: .heavy))
          .foregroundStyle(draft.bookedMinutes == draft.workedMinutes ? Theme.ink : Theme.warn)
      }
      if draft.hours.isEmpty {
        Text("No project on this week yet. Add one to book hours.")
          .font(.reading).foregroundStyle(Theme.muted)
      }
      ForEach($draft.hours) { $row in
        HStack(spacing: 10) {
          Swatch(color: ProjectPalette.color(for: row.id))
          Text(row.project.projectLabel).font(.readingStrong).lineLimit(1)
          Spacer(minLength: 8)
          Button("Fill rest") { row.text = Format.hours(draft.restMinutes(for: row)) }
            .buttonStyle(.blockQuiet)
            .help("Book the time that is not booked on other projects")
            .disabled(draft.restMinutes(for: row) <= 0)
          timeField($row.text, "0:00", .hours(row.id), isDuration: true)
        }
      }
      Button("Add a project…") { isChoosingProject = true }.buttonStyle(.block)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .disabled(isLocked)
    .panel()
  }

  private var footer: some View {
    HStack {
      Button("Cancel") { dismiss() }
        .buttonStyle(.block)
        .keyboardShortcut(.cancelAction)
      Spacer()
      if isSaving {
        ProgressView().controlSize(.small)
      }
      Text("⌘↩").font(.note).foregroundStyle(Theme.muted)
      Button("Save") { Task { await save() } }
        .buttonStyle(.blockPrimary)
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(isSaving || isLocked)
    }
  }

  // MARK: Fields

  private func timeField(
    _ text: Binding<String>, _ placeholder: String, _ field: EditorField, isDuration: Bool = false
  ) -> some View {
    let isValid =
      isDuration
      ? TimeInput.duration(text.wrappedValue) != .invalid
      : TimeInput.clock(text.wrappedValue) != .invalid
    return TimeField(
      text: text, placeholder: placeholder, isValid: isValid, field: field, focus: $focus,
      submit: { submit(field) }
    )
  }

  // Enter writes the time in full, then goes to the next box.
  private func submit(_ field: EditorField) {
    draft.normalize(field)
    let order = draft.fieldOrder
    guard let index = order.firstIndex(of: field), index + 1 < order.count else {
      focus = nil
      return
    }
    focus = order[index + 1]
  }

  private func length(of period: PeriodDraft) -> String {
    let minutes = draft.minutes(of: period)
    return minutes > 0 ? Format.hours(minutes) : ""
  }

  // MARK: Saving

  private func save() async {
    error = nil
    let edit: DayEdit
    do {
      edit = try draft.makeEdit(dayKey: dayKey)
    } catch {
      self.error = error.localizedDescription
      return
    }
    guard edit.periods != originalPeriods || !edit.hours.isEmpty else {
      dismiss()
      return
    }
    isSaving = true
    let failure = await model.timesheet.save(edit)
    isSaving = false
    if let failure {
      error = failure
    } else {
      dismiss()
    }
  }
}
