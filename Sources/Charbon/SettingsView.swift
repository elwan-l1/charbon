import CharbonCore
import SwiftUI

struct SettingsView: View {
  @Bindable var model: SettingsModel
  @State private var isChoosingProject = false

  var body: some View {
    Form {
      projectSection
      workingTimeSection
    }
    .formStyle(.grouped)
    .frame(width: 480, height: 380)
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
