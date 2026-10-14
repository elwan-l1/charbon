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

/// A project and activity pair, which hours can be booked on.
package struct ProjectChoice: Codable, Hashable, Identifiable, Sendable {
  package var projectId: Int
  package var activityId: Int
  package var projectLabel: String
  package var activityLabel: String

  package init(projectId: Int, activityId: Int, projectLabel: String, activityLabel: String) {
    self.projectId = projectId
    self.activityId = activityId
    self.projectLabel = projectLabel
    self.activityLabel = activityLabel
  }

  package var id: String {
    "\(projectId)/\(activityId)"
  }

  package var displayName: String {
    activityLabel.isEmpty ? projectLabel : "\(projectLabel) · \(activityLabel)"
  }

  package func matches(_ entry: ProjectHours) -> Bool {
    entry.projectId == projectId && entry.activityId == activityId
  }

  package func matches(_ row: WeekProject) -> Bool {
    row.projectId == projectId && row.activityId == activityId
  }

  /// One choice per activity of each project.
  package static func choices(from projects: [ProjectSummary]) -> [ProjectChoice] {
    projects.flatMap { project in
      project.activities.map {
        ProjectChoice(
          projectId: project.id,
          activityId: $0.id,
          projectLabel: project.label,
          activityLabel: $0.title
        )
      }
    }
  }
}
