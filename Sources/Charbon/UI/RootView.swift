import CharbonCore
import SwiftUI

/// The window: a sidebar, and the screen that is chosen.
struct RootView: View {
  @Bindable var model: AppModel

  var body: some View {
    Group {
      if model.settings.settings.hasCompletedOnboarding {
        HStack(spacing: 0) {
          SidebarView(model: model)
          VStack(spacing: 0) {
            if let problem = model.sessionProblem {
              ProblemNotice(problem: problem, showsContact: model.showsSessionContact)
                .padding(.horizontal, 28)
                .padding(.top, 28)
            }
            content
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
      } else {
        OnboardingView(model: model)
      }
    }
    .background(Theme.paper)
    .ignoresSafeArea()
    .onChange(of: model.settings.settings) { model.settings.commit() }
    .sheet(item: $model.editing) { day in
      DayEditorView(model: model, dayKey: day.id)
    }
  }

  @ViewBuilder
  private var content: some View {
    // the settings and the logs stay reachable when there is no session
    if model.screen == .settings || model.screen == .logs {
      screen
    } else {
      session
    }
  }

  @ViewBuilder
  private var session: some View {
    let hasData = model.timesheet.snapshot != nil
    switch model.sessionState {
    case .loginRequired:
      LoginPrompt(model: model, canRetry: false)
    case .failed:
      if hasData {
        screen
      } else {
        LoginPrompt(model: model, canRetry: true)
      }
    case .unknown, .checking:
      if hasData {
        screen
      } else {
        checking
      }
    case .signedIn:
      screen
    }
  }

  private var checking: some View {
    VStack(spacing: 16) {
      LogoMark(size: 64)
      ProgressView().controlSize(.small)
      Text("Checking your session…").font(.system(size: 13)).foregroundStyle(Theme.muted)
    }
  }

  @ViewBuilder
  private var screen: some View {
    switch model.screen {
    case .today: TodayView(model: model)
    case .week: WeekView(model: model)
    case .month: MonthView(model: model)
    case .settings: SettingsScreen(model: model)
    case .logs: LogsView()
    }
  }
}

/// Shown when there is no session: one button to log in through the HES-SO page.
struct LoginPrompt: View {
  let model: AppModel
  let canRetry: Bool

  var body: some View {
    VStack(spacing: 22) {
      LogoMark(size: 96)
      Text("Log in to Timbrage")
        .font(.system(size: 28, weight: .heavy))
      Text("Charbon keeps your session alive once you have logged in with HES-SO.")
        .font(.system(size: 14))
        .foregroundStyle(Theme.muted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 360)
      Button("Log in") { model.session.showLogin() }
        .buttonStyle(.blockHero)
      if canRetry {
        Button("Try again") { Task { await model.session.renewNow(because: "you asked") } }
          .buttonStyle(.block)
      }
    }
    .padding(40)
  }
}

struct SidebarView: View {
  let model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 10) {
        LogoMark(size: 34)
        Text("CHARBON").font(.system(size: 15, weight: .black)).tracking(2.2)
      }
      .padding(.top, 46)
      .padding(.bottom, 28)

      ForEach(Array(Screen.allCases.prefix(3).enumerated()), id: \.element) { index, screen in
        SidebarRow(screen: screen, shortcut: "⌘\(index + 1)", model: model)
      }

      Spacer()
      SidebarRow(screen: .settings, shortcut: "⌘,", model: model)
      SidebarRow(screen: .logs, shortcut: "", model: model)
      sessionLine.padding(.top, 10).padding(.leading, 4)
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 20)
    .frame(width: 196)
  }

  private var sessionLine: some View {
    HStack(spacing: 8) {
      Swatch(color: sessionColor, size: 11)
      Text(sessionText).font(.note).foregroundStyle(Theme.muted)
    }
  }

  private var sessionColor: Color {
    switch model.sessionState {
    case .signedIn: Theme.good
    case .unknown, .checking: Theme.warn
    case .loginRequired, .failed: Theme.bad
    }
  }

  private var sessionText: String {
    switch model.sessionState {
    case .signedIn: "Logged in"
    case .unknown, .checking: "Checking…"
    case .loginRequired: "Logged out"
    case .failed: "Offline"
    }
  }
}

private struct SidebarRow: View {
  let screen: Screen
  let shortcut: String
  let model: AppModel
  @State private var isHovering = false

  private var isSelected: Bool { model.screen == screen }

  var body: some View {
    Button {
      model.screen = screen
    } label: {
      HStack(spacing: 10) {
        Image(systemName: screen.symbol).frame(width: 20)
        Text(screen.title).font(.system(size: 14, weight: .heavy))
        Spacer()
        Text(shortcut).font(.system(size: 12, weight: .semibold)).opacity(0.7)
      }
      .foregroundStyle(isSelected ? Theme.paper : Theme.ink)
      .padding(.horizontal, 12)
      .frame(height: 42)
      .background(
        Rectangle()
          .fill(isSelected ? Theme.ink : (isHovering ? Theme.hairline : .clear))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
    .padding(.bottom, 4)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
