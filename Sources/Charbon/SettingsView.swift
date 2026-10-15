import CharbonCore
import SwiftUI

struct SettingsView: View {
  @Bindable var model: SettingsModel
  @State private var isChoosingProject = false

  var body: some View {
    Form {
      menuBarSection
      projectSection
      workingTimeSection
      paySection
    }
    .formStyle(.grouped)
    .frame(width: 480, height: 720)
    .onChange(of: model.settings) { model.commit() }
    .sheet(isPresented: $isChoosingProject) {
      ProjectPickerView(model: model)
    }
  }

  private var projectSection: some View {
    Section {
      LabeledContent("Default project") {
        Text(model.settings.defaultProject?.displayName ?? "None")
          .foregroundStyle(model.settings.defaultProject == nil ? .secondary : .primary)
          .multilineTextAlignment(.trailing)
          .textSelection(.enabled)
      }
      HStack {
        Spacer()
        if model.settings.defaultProject != nil {
          Button("Clear") { model.settings.defaultProject = nil }
        }
        Button("Choose…") { isChoosingProject = true }
      }
    } header: {
      Text("Project")
    } footer: {
      Text(
        "Clocking out books the time worked today on this project. "
          + "Hours already booked on other projects are left alone."
      )
    }
  }

  private var menuBarSection: some View {
    Section {
      Picker("Show next to the icon", selection: $model.settings.menuBarDisplay) {
        ForEach(MenuBarDisplay.allCases, id: \.self) { display in
          Text(display.title).tag(display)
        }
      }
      LabeledContent("Example") {
        Text(model.settings.menuBarDisplay.example).foregroundStyle(.secondary)
      }
    } header: {
      Text("Menu bar")
    } footer: {
      Text(
        "Shown while you are clocked in and after you have worked today. "
          + "Choices that need the day's hours or an hourly rate show the time worked until known."
      )
    }
  }

  private var usesContractHours: Binding<Bool> {
    Binding(
      get: { model.settings.dailyHoursOverride == nil },
      set: { model.settings.dailyHoursOverride = $0 ? nil : 8.4 }
    )
  }

  private var workingTimeSection: some View {
    Section {
      Toggle("Use the hours from my contract", isOn: usesContractHours)
      if let hours = model.settings.dailyHoursOverride {
        LabeledContent("Hours per day") {
          TextField(
            "Hours",
            value: Binding(
              get: { hours },
              set: { model.settings.dailyHoursOverride = max($0, 0) }
            ),
            format: .number.precision(.fractionLength(0...2))
          )
          .labelsHidden()
          .multilineTextAlignment(.trailing)
          .frame(width: 80)
        }
      }
    } header: {
      Text("Working time")
    } footer: {
      Text("Sets the hours the menu compares your day and week with.")
    }
  }

  private var paySection: some View {
    Section {
      Picker("Hourly rate", selection: $model.settings.pay.mode) {
        Text("From salary").tag(RateMode.salary)
        Text("Manual").tag(RateMode.hourlyRate)
      }
      .pickerStyle(.segmented)

      switch model.settings.pay.mode {
      case .salary:
        salaryFields
      case .hourlyRate:
        LabeledContent("Rate per hour") {
          TextField(
            "Rate",
            value: $model.settings.pay.hourlyRate,
            format: .number.precision(.fractionLength(0...2))
          )
          .labelsHidden()
          .multilineTextAlignment(.trailing)
          .frame(width: 100)
        }
      }
    } header: {
      Text("Pay")
    } footer: {
      Text(
        model.settings.pay.mode == .salary
          ? "Hourly rate = yearly salary ÷ (weekly hours × 52). It only appears in your menu."
          : "Shows what you earned today and this week. It only appears in your menu."
      )
    }
  }

  @ViewBuilder
  private var salaryFields: some View {
    LabeledContent("Salary") {
      TextField(
        "Amount",
        value: $model.settings.pay.salaryAmount,
        format: .number.precision(.fractionLength(0...2)).grouping(.never)
      )
      .labelsHidden()
      .multilineTextAlignment(.trailing)
      .frame(width: 120)
    }
    Picker("Paid", selection: $model.settings.pay.salaryPeriod) {
      Text("Per month").tag(SalaryPeriod.monthly)
      Text("Per year").tag(SalaryPeriod.yearly)
    }
    if model.settings.pay.salaryPeriod == .monthly {
      Picker("Installments", selection: $model.settings.pay.installmentsPerYear) {
        Text("12 per year").tag(12)
        Text("13 per year").tag(13)
      }
    }
  }
}

/// Lets the user pick the default project from everything Timbrage offers.
struct ProjectPickerView: View {
  @Bindable var model: SettingsModel
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        TextField("Search projects", text: $query)
          .textFieldStyle(.roundedBorder)
        Button("Cancel") { dismiss() }
          .keyboardShortcut(.cancelAction)
      }
      .padding()
      Divider()
      content
    }
    .frame(width: 520, height: 460)
    .task { await model.loadProjectsIfNeeded() }
  }

  @ViewBuilder
  private var content: some View {
    if model.isLoadingProjects {
      ProgressView("Loading projects…").frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let error = model.projectsError {
      VStack(spacing: 12) {
        placeholder(error)
        Button("Try Again") { Task { await model.reloadProjects() } }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      list
    }
  }

  private var list: some View {
    let matches = model.matches(for: query)
    return List {
      ForEach(matches.prefix(150)) { row($0) }
      if matches.count > 150 {
        Text("Keep typing to narrow down \(matches.count) results…")
          .foregroundStyle(.secondary)
      }
    }
    .overlay {
      if matches.isEmpty {
        placeholder("No project matches “\(query)”.")
      }
    }
  }

  private func row(_ choice: ProjectChoice) -> some View {
    Button {
      model.settings.defaultProject = choice
      dismiss()
    } label: {
      HStack {
        VStack(alignment: .leading) {
          Text(choice.projectLabel)
          Text(choice.activityLabel).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        if model.settings.defaultProject?.id == choice.id {
          Image(systemName: "checkmark").foregroundStyle(.tint)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func placeholder(_ text: String) -> some View {
    Text(text)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
