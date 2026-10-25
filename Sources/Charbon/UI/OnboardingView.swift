import CharbonCore
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
  case welcome
  case account
  case appearance
  case workTime
  case pay
  case menuBar
  case startup
  case done

  var title: String {
    switch self {
    case .welcome: "Welcome to Charbon"
    case .account: "Log in to Timbrage"
    case .appearance: "Pick a look"
    case .workTime: "How many hours do you work?"
    case .pay: "Want to see what you earn?"
    case .menuBar: "The menu bar"
    case .startup: "Last details"
    case .done: "You are all set"
    }
  }

  var subtitle: String {
    switch self {
    case .welcome:
      "Clock in and out, see where your hours go, and never lose your session again."
    case .account:
      "Charbon logs in with your HES-SO account and keeps the session alive for you. "
        + "Your password is never seen by Charbon."
    case .appearance:
      "Light, dark, or the same as your Mac. Change it any time in Settings."
    case .workTime:
      "Charbon shows how far your day is and when it ends."
    case .pay:
      "Optional. It stays on this Mac and shows next to your hours."
    case .menuBar:
      "Clock in and out without opening the app. Choose what it shows next to the clock."
    case .startup:
      "Pick the project to book your hours on when you clock out, "
        + "and if Charbon starts with your Mac."
    case .done:
      "This is what you chose. Every choice lives in Settings if you change your mind."
    }
  }
}

/// The first launch: a short tour that asks the few things the app needs, with a live preview.
struct OnboardingView: View {
  let model: AppModel
  @State private var step: OnboardingStep
  @State private var isChoosingProject = false

  init(model: AppModel, step: OnboardingStep = .welcome) {
    self.model = model
    _step = State(initialValue: step)
  }

  private var settings: SettingsModel { model.settings }
  private var steps: [OnboardingStep] { OnboardingStep.allCases }

  var body: some View {
    VStack(spacing: 0) {
      topBar
      if step == .welcome {
        welcome
      } else {
        VStack(alignment: .leading, spacing: 24) {
          header
          ScrollView { controls.padding(.bottom, 8).padding(.horizontal, 2) }
          bottomBar
        }
        .frame(maxWidth: 540)
        .padding(.top, 16)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
      }
    }
    .sheet(isPresented: $isChoosingProject) {
      ProjectPickerView(model: settings, selectedID: settings.settings.defaultProject?.id) {
        settings.settings.defaultProject = $0
      }
    }
  }

  // MARK: Bars

  // The steps sit in the middle of the window on their own, so they do not move when the skip
  // button goes away on the last step.
  private var topBar: some View {
    ZStack {
      HStack(spacing: 18) {
        HStack(spacing: 10) {
          LogoMark(size: 30)
          Text("CHARBON").font(.system(size: 14, weight: .black)).tracking(2.2)
        }
        Spacer()
        if step != .done {
          Button("Skip setup", action: finish).buttonStyle(.blockQuiet)
            .help("Keep the defaults. You can change everything in Settings.")
        }
      }
      if step != .welcome {
        progress
      }
    }
    .padding(.horizontal, 48)
    .padding(.top, 38)
    .frame(height: 84)
  }

  private var progress: some View {
    HStack(spacing: 6) {
      ForEach(steps.dropFirst(), id: \.rawValue) { item in
        Rectangle()
          .fill(
            item.rawValue < step.rawValue
              ? Theme.ink : (item == step ? Theme.ember : Theme.hairline)
          )
          .frame(width: 30, height: 9)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Step \(step.rawValue) of \(steps.count - 1)")
  }

  private var bottomBar: some View {
    HStack {
      Button("Back") { move(-1) }.buttonStyle(.block)
      Spacer()
      Text("Step \(step.rawValue) of \(steps.count - 1)").font(.note).foregroundStyle(Theme.muted)
      Spacer()
      Button(step == .done ? "Open Charbon" : "Continue") {
        if step == .done {
          finish()
        } else {
          move(1)
        }
      }
      .buttonStyle(.blockHero)
      .keyboardShortcut(.defaultAction)
    }
  }

  // MARK: Steps

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      Eyebrow(text: "Step \(step.rawValue) of \(steps.count - 1)", color: Theme.ember)
      Text(step.title).font(.system(size: 34, weight: .heavy))
        .fixedSize(horizontal: false, vertical: true)
      Text(step.subtitle).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var welcome: some View {
    VStack(spacing: 26) {
      Spacer()
      LogoMark(size: 150)
      Text("Welcome to Charbon").font(.system(size: 44, weight: .heavy))
      Text(OnboardingStep.welcome.subtitle)
        .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.muted)
        .multilineTextAlignment(.center).frame(maxWidth: 480)
      VStack(alignment: .leading, spacing: 10) {
        bullet("Clock in and out in one click, from the app or the menu bar")
        bullet("See your week and month, with the share of each project")
        bullet("Fix a forgotten clock out in seconds")
      }
      Button("Get started") { move(1) }
        .buttonStyle(.blockHero)
        .keyboardShortcut(.defaultAction)
        .padding(.top, 8)
      Text("Setup takes about a minute. You can skip any step.")
        .font(.note).foregroundStyle(Theme.muted)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  private func bullet(_ text: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "checkmark.square.fill").foregroundStyle(Theme.ember)
      Text(text).font(.readingStrong)
    }
  }

  @ViewBuilder
  private var controls: some View {
    switch step {
    case .welcome:
      EmptyView()
    case .account:
      account
    case .appearance:
      VStack(spacing: 14) { AppearanceChoice(model: settings) }
    case .workTime:
      WorkingTimeEditor(model: settings)
    case .pay:
      PayEditor(model: settings, contractMinutes: model.contractWeekMinutes)
    case .menuBar:
      MenuBarEditor(model: settings, contractMinutes: model.contractWeekMinutes)
    case .startup:
      StartupEditor(
        model: settings,
        isSignedIn: model.sessionState.isSignedIn,
        chooseProject: { isChoosingProject = true }
      )
    case .done:
      OnboardingSummary(model: model)
    }
  }

  private var account: some View {
    VStack(alignment: .leading, spacing: 16) {
      if model.sessionState.isSignedIn {
        Label("You are logged in", systemImage: "checkmark.circle.fill")
          .font(.heading).foregroundStyle(Theme.good)
        Text("Charbon renews the session on its own, so you stay logged in.")
          .font(.reading).foregroundStyle(Theme.muted)
      } else {
        CredentialsEditor(model: model)
        Text("Or log in by hand in a window. You can also do this later.")
          .font(.note).foregroundStyle(Theme.muted)
        Button("Log in with HES-SO") { model.session.showLogin() }.buttonStyle(.block)
      }
    }
  }

  // MARK: Moving

  private func move(_ delta: Int) {
    guard let next = OnboardingStep(rawValue: step.rawValue + delta) else {
      return
    }
    withAnimation(.easeOut(duration: 0.15)) { step = next }
  }

  private func finish() {
    settings.settings.hasCompletedOnboarding = true
    settings.commit()
    model.screen = .today
  }
}
