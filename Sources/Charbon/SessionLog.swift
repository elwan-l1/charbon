import Foundation
import Observation

struct SessionLogEntry: Codable, Identifiable, Equatable {
  enum Level: String, Codable {
    case info, success, warning, error
  }

  var id = UUID()
  let date: Date
  let level: Level
  let title: String
  let detail: String?
}

/// What Charbon did with the session and when, kept on disk between launches.
///
/// It holds names, codes and times, never a password, a code or a cookie.
@MainActor
@Observable
final class SessionLog {
  static let shared = SessionLog()

  private static let limit = 500
  private static let textTime: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = .current
    return formatter
  }()

  /// Oldest first.
  private(set) var entries: [SessionLogEntry]

  @ObservationIgnored private let url: URL

  private init() {
    let folder = URL.applicationSupportDirectory.appending(
      path: "Charbon", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    url = folder.appending(path: "session-log.json")
    entries =
      (try? Data(contentsOf: url)).flatMap {
        try? JSONDecoder().decode([SessionLogEntry].self, from: $0)
      }
      ?? []
  }

  func add(_ level: SessionLogEntry.Level, _ title: String, _ detail: String? = nil) {
    entries.append(SessionLogEntry(date: Date(), level: level, title: title, detail: detail))
    if entries.count > Self.limit {
      entries.removeFirst(entries.count - Self.limit)
    }
    save()
  }

  func clear() {
    entries = []
    save()
  }

  /// The whole log as text, oldest first, to paste in a mail.
  var text: String {
    entries.map {
      let time = Self.textTime.string(from: $0.date)
      return "\(time) [\($0.level.rawValue)] \($0.title)" + ($0.detail.map { " - \($0)" } ?? "")
    }
    .joined(separator: "\n")
  }

  private func save() {
    try? JSONEncoder().encode(entries).write(to: url, options: .atomic)
  }
}
