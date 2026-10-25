import CharbonCore
import SwiftUI

/// The mail a user sends to the maintainer, already filled in.
enum ContactMail {
  static func url(for problem: CharbonProblem) -> URL? {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    return problem.mailURL(
      appVersion: version ?? "unknown",
      system: ProcessInfo.processInfo.operatingSystemVersionString
    )
  }
}

/// The link that opens that mail.
struct ContactLink: View {
  let problem: CharbonProblem

  var body: some View {
    if let url = ContactMail.url(for: problem) {
      Link(destination: url) {
        Text("Still broken? Write to \(Charbon.maintainerEmail)")
          .font(.readingStrong)
          .foregroundStyle(Theme.ember)
          .underline()
      }
      .buttonStyle(.plain)
    }
  }
}

/// The session has a problem: its code, one sentence, and after a few tries the way to write.
struct ProblemNotice: View {
  let problem: CharbonProblem
  let showsContact: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.bad)
        Text(problem.headline).font(.readingStrong)
        Spacer(minLength: 0)
      }
      if showsContact {
        ContactLink(problem: problem)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .panel(padding: 14, outline: Theme.bad)
  }
}
