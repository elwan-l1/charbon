import CharbonCore
import SwiftUI

/// What the menu bar item would show for a day in the middle of the afternoon.
struct MenuBarSample {
  static let workedMinutes = 158

  let display: MenuBarDisplay
  let settings: CharbonSettings
  /// The weekly hours of the contract, in minutes, when they are known.
  let contractMinutes: Int?

  var rate: Double? {
    settings.hourlyRate(contractMinutes: contractMinutes ?? 42 * 60)
  }

  var targetMinutes: Int {
    settings.dailyHoursOverride.map { Int(($0 * 60).rounded()) } ?? 504
  }

  /// The text next to the icon, or `nil` for the icon alone.
  var text: String? {
    display.text(
      workedMinutes: Self.workedMinutes,
      targetMinutes: targetMinutes,
      hourlyRate: rate
    )
  }

  /// Whether the format needs a pay that the user has not set yet.
  var needsPay: Bool {
    (display == .money || display == .timeAndMoney) && rate == nil
  }
}

/// A strip like the menu bar of the Mac, with the item of Charbon in it.
struct MenuBarMock: View {
  let text: String?
  var isVisible = true

  var body: some View {
    HStack(spacing: 14) {
      Spacer()
      ForEach(0..<3, id: \.self) { _ in
        Rectangle().fill(Theme.faint).frame(width: 14, height: 11)
      }
      if isVisible {
        HStack(spacing: 5) {
          LogoMark(size: 18)
          if let text {
            Text(text).font(.system(size: 13, weight: .semibold)).monospacedDigit()
          }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Rectangle().fill(Theme.ink.opacity(0.14)))
      }
      Text("Sun 17:42").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
    }
    .padding(.horizontal, 16)
    .frame(height: 34)
    .background(Rectangle().fill(Theme.ink.opacity(0.08)))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      isVisible ? "Menu bar preview: \(text ?? "icon only")" : "Menu bar preview: no item")
  }
}

/// Whether to show the item, and what it says.
struct MenuBarEditor: View {
  @Bindable var model: SettingsModel
  var contractMinutes: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Toggle(isOn: $model.settings.showsMenuBarItem) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Show Charbon in the menu bar").font(.readingStrong)
          Text("A clock next to the time of your Mac to clock in and out in two clicks.")
            .font(.note).foregroundStyle(Theme.muted)
        }
      }
      .toggleStyle(BlockToggleStyle())
      MenuBarMock(
        text: sample(model.settings.menuBarDisplay).text,
        isVisible: model.settings.showsMenuBarItem
      )
      if model.settings.showsMenuBarItem {
        VStack(spacing: 8) {
          ForEach(MenuBarDisplay.allCases, id: \.self) { display in
            formatRow(display)
          }
        }
      }
    }
  }

  private func sample(_ display: MenuBarDisplay) -> MenuBarSample {
    MenuBarSample(display: display, settings: model.settings, contractMinutes: contractMinutes)
  }

  private func formatRow(_ display: MenuBarDisplay) -> some View {
    let sample = sample(display)
    let isSelected = model.settings.menuBarDisplay == display
    return Button {
      model.settings.menuBarDisplay = display
    } label: {
      HStack(spacing: 12) {
        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
          .foregroundStyle(isSelected ? Theme.ember : Theme.muted)
        VStack(alignment: .leading, spacing: 1) {
          Text(display.title).font(.readingStrong)
          if sample.needsPay {
            Text("Set your pay to see this. Until then it shows the time worked.")
              .font(.note).foregroundStyle(Theme.muted)
          }
        }
        Spacer()
        Text(sample.text ?? "icon only").font(.figure(14, weight: .heavy))
          .foregroundStyle(Theme.ink)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(
        Rectangle().outlined(
          fill: isSelected ? Theme.surface : Theme.paper,
          line: isSelected ? Theme.ember : Theme.hairline,
          width: isSelected ? 3 : 1.5
        )
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
