import CharbonCore
import SwiftUI

/// Lets the user pick a project from everything Timbrage offers.
struct ProjectPickerView: View {
  @Bindable var model: SettingsModel
  var selectedID: String?
  let onSelect: (ProjectChoice) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
        TextField("Search projects", text: $query)
          .textFieldStyle(.plain)
          .font(.reading)
        Button("Cancel") { dismiss() }
          .buttonStyle(.block)
          .keyboardShortcut(.cancelAction)
      }
      .padding(18)
      Rectangle().fill(Theme.ink).frame(height: Theme.stroke)
      content
    }
    .frame(width: 560, height: 480)
    .background(Theme.paper)
    .task { await model.loadProjectsIfNeeded() }
  }

  @ViewBuilder
  private var content: some View {
    if model.isLoadingProjects {
      ProgressView("Loading projects…").frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let error = model.projectsError {
      VStack(spacing: 14) {
        placeholder(error)
        Button("Try again") { Task { await model.reloadProjects() } }.buttonStyle(.block)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      list
    }
  }

  private var list: some View {
    let matches = model.matches(for: query)
    return ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(matches.prefix(150)) { row($0) }
        if matches.count > 150 {
          Text("Keep typing to narrow down \(matches.count) results…")
            .font(.note).foregroundStyle(Theme.muted).padding()
        }
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
      onSelect(choice)
      dismiss()
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(choice.projectLabel).font(.readingStrong)
          Text(choice.activityLabel).font(.note).foregroundStyle(Theme.muted)
        }
        Spacer()
        if selectedID == choice.id {
          Image(systemName: "checkmark.square.fill").foregroundStyle(Theme.ember)
        }
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 10)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func placeholder(_ text: String) -> some View {
    Text(text)
      .font(.reading)
      .foregroundStyle(Theme.muted)
      .multilineTextAlignment(.center)
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
