import Foundation

package struct ProjectActivity: Decodable, Equatable, Sendable {
  package let id: Int
  /// Like `100 - Projet`.
  package let title: String

  private enum CodingKeys: String, CodingKey {
    case id = "Id"
    case title = "Title"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(Int.self, forKey: .id)
    title = container.lossy(.title, default: "")
  }
}

/// A project of `TimeSheet/GetProjects`.
package struct ProjectSummary: Decodable, Equatable, Sendable {
  package let id: Int
  /// The number people know the project by, like `123456`.
  package let number: Int?
  package let acronym: String
  package let activities: [ProjectActivity]

  private enum CodingKeys: String, CodingKey {
    case id = "Id"
    case number = "ProjectHESSOId"
    case acronym = "Acronym"
    case activities = "Activities"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(Int.self, forKey: .id)
    number = try? container.decodeIfPresent(Int.self, forKey: .number)
    acronym = container.lossy(.acronym, default: "")
    activities = container.lossy(.activities, default: [ProjectActivity]())
  }

  /// Like `123456 - Demo`, as the timesheet shows it.
  package var label: String {
    guard let number else {
      return acronym
    }
    return "\(number) - \(acronym)"
  }
}
