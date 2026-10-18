import CharbonCore
import SwiftUI

/// The settings, inside the main window.
struct SettingsScreen: View {
  let model: AppModel
  @State private var isChoosingProject = false

  var body: some View {
    let settings = model.settings
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Text("Settings").font(.title)
        section(
          "Appearance", help: "Light, dark, or the same as your Mac. It changes at once."
        ) {
          AppearanceChoice(model: settings)
        }
        section(
          "Working time", help: "What Charbon compares your day and week with."
        ) {
          WorkingTimeEditor(model: settings)
        }
        section(
          "Pay", help: "Shows what you earned. It stays on this Mac and Timbrage never sees it."
        ) {
          PayEditor(model: settings, contractMinutes: model.contractWeekMinutes)
        }
        section(
          "Menu bar", help: "The clock next to the time of your Mac, and what it says."
        ) {
          MenuBarEditor(model: settings, contractMinutes: model.contractWeekMinutes)
        }
        section("Project and startup", help: nil) {
          StartupEditor(
            model: settings,
            isSignedIn: model.sessionState.isSignedIn,
            chooseProject: { isChoosingProject = true }
          )
        }
        section("Account", help: nil) { account }
      }
      .padding(28)
      .frame(maxWidth: 760, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .onAppear { settings.refreshLaunchAtLogin() }
    .sheet(isPresented: $isChoosingProject) {
      ProjectPickerView(model: settings, selectedID: settings.settings.defaultProject?.id) {
        settings.settings.defaultProject = $0
      }
    }
  }

  private func section<Content: View>(
    _ title: String, help: String?, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      SectionTitle(title: title, help: help)
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(padding: 22)
  }

  private var account: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 12) {
        Image(
          systemName: model.sessionState.isSignedIn ? "checkmark.circle.fill" : "xmark.circle.fill"
        )
        .foregroundStyle(model.sessionState.isSignedIn ? Theme.good : Theme.bad)
        Text(model.sessionState.isSignedIn ? "Logged in to Timbrage" : "Not logged in")
          .font(.readingStrong)
        Spacer()
        if model.sessionState.isSignedIn {
          Button("Log out") { Task { await model.session.logOut() } }.buttonStyle(.block)
        } else {
          Button("Log in") { model.session.showLogin() }.buttonStyle(.blockPrimary)
        }
      }
      HStack(spacing: 12) {
        Text("Charbon \(Self.version)").font(.note).foregroundStyle(Theme.muted)
        Spacer()
        Button("Show the welcome tour again") {
          model.settings.settings.hasCompletedOnboarding = false
        }
        .buttonStyle(.blockQuiet)
      }
    }
  }

  private static var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
  }
}

extension SessionController.State {
  var isSignedIn: Bool {
    if case .signedIn = self {
      return true
    }
    return false
  }
}
