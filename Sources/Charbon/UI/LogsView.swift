import AppKit
import SwiftUI

/// What Charbon did with the session, newest first.
struct LogsView: View {
  private let log = SessionLog.shared

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        HStack(alignment: .firstTextBaseline) {
          Text("Logs").font(.title)
          Spacer()
          Button("Copy") { copy() }.buttonStyle(.block).disabled(log.entries.isEmpty)
          Button("Clear") { log.clear() }.buttonStyle(.block).disabled(log.entries.isEmpty)
        }
        Text("Every login, renewal and retry, with the time. No password, code or cookie is kept.")
          .font(.reading).foregroundStyle(Theme.muted)
        if log.entries.isEmpty {
          Text("Nothing yet.").font(.reading).foregroundStyle(Theme.muted)
        } else {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(log.entries.reversed())) { entry in
              LogRow(entry: entry)
            }
          }
          .panel(padding: 8)
        }
      }
      .padding(28)
      .frame(maxWidth: 900, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
  }

  private func copy() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(log.text, forType: .string)
  }
}

private struct LogRow: View {
  let entry: SessionLogEntry

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Swatch(color: color, size: 11)
      Text(time).font(.figure(12, weight: .semibold)).foregroundStyle(Theme.muted)
        .frame(width: 118, alignment: .leading)
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.title).font(.readingStrong)
        if let detail = entry.detail {
          Text(detail).font(.note).foregroundStyle(Theme.muted)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var color: Color {
    switch entry.level {
    case .info: Theme.faint
    case .success: Theme.good
    case .warning: Theme.warn
    case .error: Theme.bad
    }
  }

  private var time: String {
    if Calendar.current.isDateInToday(entry.date) {
      return entry.date.formatted(.dateTime.hour().minute().second())
    }
    return entry.date.formatted(.dateTime.day().month(.abbreviated).hour().minute().second())
  }
}
