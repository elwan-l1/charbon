import CharbonCore
import SwiftUI

/// The choices of the user, in a list.
struct OnboardingSummary: View {
  let model: AppModel

  var body: some View {
    let settings = model.settings.settings
    let rate = settings.hourlyRate(contractMinutes: model.contractWeekMinutes ?? 42 * 60)
    VStack(spacing: 0) {
      row("Appearance", settings.appearance.title)
      row(
        "Hours",
        settings.dailyHoursOverride.map {
          Format.hours(Int(($0 * 60).rounded())) + " a day"
        } ?? "From my contract")
      row(
        "Pay",
        rate.map {
          Format.rate($0)
        } ?? "Not shown")
      row(
        "Menu bar",
        settings.showsMenuBarItem ? settings.menuBarDisplay.title : "Hidden")
      row("Default project", settings.defaultProject?.projectLabel ?? "None")
      row("Session", model.sessionState.isSignedIn ? "Logged in" : "Not logged in yet")
    }
    .panel(padding: 6)
  }

  private func row(_ title: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title).font(.note).foregroundStyle(Theme.muted)
      Spacer(minLength: 12)
      Text(value).font(.readingStrong).multilineTextAlignment(.trailing)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 11)
  }
}
