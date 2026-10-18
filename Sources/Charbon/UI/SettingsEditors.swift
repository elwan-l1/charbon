import CharbonCore
import SwiftUI

/// How many hours a day the user works: what the contract says, or their own number.
struct WorkingTimeEditor: View {
  @Bindable var model: SettingsModel

  private static let contractDay = 8.4

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        ChoiceCard(
          title: "My contract",
          subtitle: "Timbrage tells Charbon the hours of each day. Holidays and part-time work.",
          isSelected: model.settings.dailyHoursOverride == nil,
          action: { model.settings.dailyHoursOverride = nil },
          content: { EmptyView() }
        )
        ChoiceCard(
          title: "My own hours",
          subtitle: "The same number of hours on every working day.",
          isSelected: model.settings.dailyHoursOverride != nil,
          action: {
            if model.settings.dailyHoursOverride == nil {
              model.settings.dailyHoursOverride = Self.contractDay
            }
          },
          content: { EmptyView() }
        )
      }
      if let hours = model.settings.dailyHoursOverride {
        HStack(spacing: 16) {
          NumberStepper(
            value: Binding(
              get: { hours },
              set: { model.settings.dailyHoursOverride = $0 }
            ),
            step: 0.25,
            range: 1...12,
            format: { Format.hours(Int(($0 * 60).rounded())) }
          )
          Text("per day  ·  \(Format.hours(Int((hours * 5 * 60).rounded()))) per week")
            .font(.reading).foregroundStyle(Theme.muted)
        }
      }
    }
  }
}

/// The salary or hourly rate, to show what the user earned.
///
/// It never leaves the Mac.
struct PayEditor: View {
  @Bindable var model: SettingsModel
  var contractMinutes: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Segmented(
        options: [(.off, "No money"), (.salary, "Salary"), (.hourlyRate, "Hourly rate")],
        selection: $model.settings.pay.mode
      )
      switch model.settings.pay.mode {
      case .off:
        Text("Charbon shows hours only.").font(.reading).foregroundStyle(Theme.muted)
      case .salary:
        salaryFields
      case .hourlyRate:
        row("Rate per hour") {
          TextField("0", value: $model.settings.pay.hourlyRate, format: amount)
            .multilineTextAlignment(.trailing).flatField(width: 130)
          Text(RateCalculator.currencyCode).font(.readingStrong)
        }
      }
      if let rate = model.settings.hourlyRate(contractMinutes: contractMinutes ?? 42 * 60) {
        Label {
          Text(
            "About " + Format.rate(rate)
          )
          .font(.readingStrong)
        } icon: {
          Image(systemName: "banknote")
        }
      }
    }
  }

  private var amount: FloatingPointFormatStyle<Double> {
    .number.precision(.fractionLength(0...2)).grouping(.never)
  }

  @ViewBuilder
  private var salaryFields: some View {
    row("Salary") {
      TextField("0", value: $model.settings.pay.salaryAmount, format: amount)
        .multilineTextAlignment(.trailing).flatField(width: 150)
      Text(RateCalculator.currencyCode).font(.readingStrong)
    }
    row("Paid") {
      Segmented(
        options: [(.monthly, "Per month"), (.yearly, "Per year")],
        selection: $model.settings.pay.salaryPeriod
      )
      .frame(width: 240)
    }
    if model.settings.pay.salaryPeriod == .monthly {
      row("Installments") {
        Segmented(
          options: [(12, "12 a year"), (13, "13 a year")],
          selection: $model.settings.pay.installmentsPerYear
        )
        .frame(width: 240)
      }
    }
    Text("Hourly rate = yearly salary ÷ (weekly hours × 52).")
      .font(.note).foregroundStyle(Theme.muted)
  }

  private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    HStack(spacing: 12) {
      Text(title).font(.readingStrong).frame(width: 110, alignment: .leading)
      content()
      Spacer(minLength: 0)
    }
  }
}

/// The default project, and whether the app opens when the Mac starts.
struct StartupEditor: View {
  @Bindable var model: SettingsModel
  let isSignedIn: Bool
  let chooseProject: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Default project").font(.readingStrong)
        HStack(spacing: 12) {
          Text(model.settings.defaultProject?.displayName ?? "None")
            .font(.reading)
            .foregroundStyle(model.settings.defaultProject == nil ? Theme.muted : Theme.ink)
            .lineLimit(2)
          Spacer(minLength: 8)
          if model.settings.defaultProject != nil {
            Button("Clear") { model.settings.defaultProject = nil }.buttonStyle(.blockQuiet)
          }
          Button("Choose…", action: chooseProject).buttonStyle(.block).disabled(!isSignedIn)
        }
        Text(
          isSignedIn
            ? "Clocking out books the time worked today on this project. "
              + "Hours already booked elsewhere stay."
            : "Log in to Timbrage first to see your projects."
        )
        .font(.note).foregroundStyle(Theme.muted)
      }
      Toggle(
        isOn: Binding(
          get: { model.launchAtLogin },
          set: { model.setLaunchAtLogin($0) }
        )
      ) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Open Charbon when I log in to my Mac").font(.readingStrong)
          Text("Keeps your session alive from the first minute.")
            .font(.note).foregroundStyle(Theme.muted)
        }
      }
      .toggleStyle(BlockToggleStyle())
    }
  }
}
