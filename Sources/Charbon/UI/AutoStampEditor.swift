import CharbonCore
import SwiftUI

/// The windows in which Charbon clocks in and out when the Mac opens or closes.
struct AutoStampEditor: View {
  @Bindable var model: SettingsModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Toggle(isOn: $model.settings.autoStamp.isEnabled) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Clock in and out by itself").font(.readingStrong)
          Text("Monday to Friday, once for each window.")
            .font(.note).foregroundStyle(Theme.muted)
        }
      }
      .toggleStyle(BlockToggleStyle())
      if model.settings.autoStamp.isEnabled {
        ForEach(AutoStampSlot.allCases, id: \.self) { slot in
          row(slot)
        }
        Text("Opens: the Mac wakes up, is unlocked or Charbon starts. Closes: it sleeps or locks.")
          .font(.note).foregroundStyle(Theme.muted)
      }
    }
  }

  private func row(_ slot: AutoStampSlot) -> some View {
    let window = Binding(
      get: { model.settings.autoStamp.window(of: slot) },
      set: { model.settings.autoStamp.setWindow($0, of: slot) }
    )
    return HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(slot.title).font(.readingStrong)
        Text(slot.isClockIn ? "Clock in when the Mac opens" : "Clock out when the Mac closes")
          .font(.note).foregroundStyle(Theme.muted)
      }
      Spacer(minLength: 8)
      ClockBox(time: window.start)
      Text("to").font(.reading).foregroundStyle(Theme.muted)
      ClockBox(time: window.end)
    }
  }
}

// A time of day typed the way people type it. It is read when the box loses focus or on Enter.
private struct ClockBox: View {
  @Binding var time: ClockTime
  @State private var text = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField("", text: $text)
      .focused($isFocused)
      .onSubmit(commit)
      .onChange(of: isFocused) {
        if !isFocused {
          commit()
        }
      }
      .onAppear { text = time.description }
      .multilineTextAlignment(.center)
      .flatField(width: 84)
  }

  private func commit() {
    if case .value(let parsed) = TimeInput.clock(text) {
      time = parsed
    }
    text = time.description
  }
}
