import AppKit
import CharbonCore

/// Clocks in and out by itself when the Mac opens or closes inside the windows of the settings.
@MainActor
final class AutoStamper {
  // A stamp that failed is tried again when the session is back, but not for long: an old time
  // would be wrong once the user has gone on with their day.
  private static let retryWindow: TimeInterval = 10 * 60

  private let settings: SettingsModel
  private let session: SessionController
  private let timesheet: TimesheetController
  private let log = SessionLog.shared

  // Slots done today, so a lock and an unlock in the same window stamp once.
  private var done: Set<String> = []
  private var pending: (slot: AutoStampSlot, date: Date)?

  init(settings: SettingsModel, session: SessionController, timesheet: TimesheetController) {
    self.settings = settings
    self.session = session
    self.timesheet = timesheet
  }

  func start() {
    let workspace = NSWorkspace.shared.notificationCenter
    observe(workspace, NSWorkspace.didWakeNotification, .opened)
    observe(workspace, NSWorkspace.willSleepNotification, .closed)
    let screen = DistributedNotificationCenter.default()
    observe(screen, Notification.Name("com.apple.screenIsUnlocked"), .opened)
    observe(screen, Notification.Name("com.apple.screenIsLocked"), .closed)
    handle(.opened)
  }

  /// A stamp may be waiting for the session.
  func sessionSignedIn() {
    Task { await runPending() }
  }

  private func observe(
    _ center: NotificationCenter, _ name: Notification.Name, _ event: AutoStampEvent
  ) {
    center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
      Task { @MainActor in self?.handle(event) }
    }
  }

  private func handle(_ event: AutoStampEvent) {
    let now = Date()
    guard let slot = settings.settings.autoStamp.slot(for: event, at: now) else {
      pending = nil
      return
    }
    guard !done.contains(Self.key(slot, now)) else {
      return
    }
    pending = (slot, now)
    Task { await runPending() }
  }

  private func runPending() async {
    guard let (slot, date) = pending, case .signedIn = session.state, !timesheet.isBusy else {
      return
    }
    pending = nil
    guard Date().timeIntervalSince(date) < Self.retryWindow else {
      return
    }
    await timesheet.refresh()
    guard let status = timesheet.snapshot?.status else {
      return
    }
    var isWorking = false
    if case .working = status {
      isWorking = true
    }
    // Already as wanted, for example clocked in by hand.
    guard isWorking != slot.isClockIn else {
      done.insert(Self.key(slot, date))
      return
    }
    let failure =
      slot.isClockIn ? await timesheet.clockIn(at: date) : await timesheet.clockOut(at: date)
    let action = slot.isClockIn ? "clock in" : "clock out"
    if let failure {
      pending = (slot, date)
      log.add(.error, "Automatic \(action) failed", failure)
      return
    }
    done.insert(Self.key(slot, date))
    log.add(
      .success, "Clocked \(slot.isClockIn ? "in" : "out") automatically",
      "\(slot.title) at \(ClockTime(date: date))")
  }

  private static func key(_ slot: AutoStampSlot, _ date: Date) -> String {
    CharbonCalendar.dayKey(date) + slot.rawValue
  }
}
