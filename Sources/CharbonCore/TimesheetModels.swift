import Foundation

/// One arrival or departure time of a period.
package struct StampTime: Codable, Equatable, Sendable {
  // What the server answers for a time that is not set. Requests use "" instead.
  package static let emptySentinel = "00:00"

  /// `0` until the first save.
  package var id: Int
  /// `HH:mm`.
  package var time: String
  package var isWarranty: Bool
  /// Must be sent back unchanged on the next save. `""` until the first save.
  package var rowVersion: String

  package init(id: Int = 0, time: String = "", isWarranty: Bool = false, rowVersion: String = "") {
    self.id = id
    self.time = time
    self.isWarranty = isWarranty
    self.rowVersion = rowVersion
  }

  private enum CodingKeys: String, CodingKey {
    case id = "Id"
    case time = "Time"
    case isWarranty = "IsWarranty"
    case rowVersion = "RowVersion"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = container.lossy(.id, default: 0)
    time = container.lossy(.time, default: "")
    isWarranty = container.lossy(.isWarranty, default: false)
    rowVersion = container.lossy(.rowVersion, default: "")
  }
}

/// The arrival and departure of one period of a day (0 is the morning, 1 the afternoon).
package struct PeriodTime: Codable, Equatable, Sendable {
  package var id: Int
  package var displayOrder: Int
  package var personId: Int
  /// Like `2026-10-12T00:00:00`.
  package var day: String
  package var arrival: StampTime
  package var departure: StampTime
  /// `1` means editable.
  package var stage: Int
  package var rowVersion: String

  package init(
    id: Int = 0,
    displayOrder: Int,
    personId: Int,
    day: String,
    arrival: StampTime = StampTime(),
    departure: StampTime = StampTime(),
    stage: Int = 1,
    rowVersion: String = ""
  ) {
    self.id = id
    self.displayOrder = displayOrder
    self.personId = personId
    self.day = day
    self.arrival = arrival
    self.departure = departure
    self.stage = stage
    self.rowVersion = rowVersion
  }

  private enum CodingKeys: String, CodingKey {
    case id = "Id"
    case displayOrder = "DisplayOrder"
    case personId = "PersonId"
    case day = "Day"
    case arrival = "ArrivalTime"
    case departure = "DepartureTime"
    case stage = "Stage"
    case rowVersion = "RowVersion"
    case errorArrival = "error_arrival"
    case errorDeparture = "error_departure"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = container.lossy(.id, default: 0)
    displayOrder = container.lossy(.displayOrder, default: 0)
    personId = container.lossy(.personId, default: 0)
    day = container.lossy(.day, default: "")
    arrival = container.lossy(.arrival, default: StampTime())
    departure = container.lossy(.departure, default: StampTime())
    stage = container.lossy(.stage, default: 1)
    rowVersion = container.lossy(.rowVersion, default: "")
  }

  package func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(displayOrder, forKey: .displayOrder)
    try container.encode(personId, forKey: .personId)
    try container.encode(day, forKey: .day)
    try container.encode(arrival, forKey: .arrival)
    try container.encode(departure, forKey: .departure)
    try container.encode(stage, forKey: .stage)
    try container.encode(rowVersion, forKey: .rowVersion)
    // The web app sets both flags when only one of the two times is filled in.
    let incomplete = arrival.time.isEmpty != departure.time.isEmpty
    try container.encode(incomplete, forKey: .errorArrival)
    try container.encode(incomplete, forKey: .errorDeparture)
  }
}

/// Hours booked on one project activity for one day.
package struct ProjectHours: Codable, Equatable, Sendable {
  /// Like `2026-10-12T00:00:00`.
  package var day: String
  package var personId: Int
  package var activityId: Int
  package var projectId: Int
  /// `H:mm`, or `""` when nothing is booked.
  package var hours: String
  package var remark: String?
  /// `1` means editable.
  package var stage: Int
  package var rowVersion: String

  package init(
    day: String,
    personId: Int,
    activityId: Int,
    projectId: Int,
    hours: String,
    remark: String? = nil,
    stage: Int = 1,
    rowVersion: String = ""
  ) {
    self.day = day
    self.personId = personId
    self.activityId = activityId
    self.projectId = projectId
    self.hours = hours
    self.remark = remark
    self.stage = stage
    self.rowVersion = rowVersion
  }

  private enum CodingKeys: String, CodingKey {
    case day = "Day"
    case personId = "PersonId"
    case activityId = "ActivityId"
    case projectId = "ProjectId"
    case hours = "Hours"
    case remark = "Remark"
    case stage = "Stage"
    case rowVersion = "RowVersion"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    day = container.lossy(.day, default: "")
    personId = container.lossy(.personId, default: 0)
    activityId = container.lossy(.activityId, default: 0)
    projectId = container.lossy(.projectId, default: 0)
    hours = container.lossy(.hours, default: "")
    remark = try? container.decodeIfPresent(String.self, forKey: .remark)
    stage = container.lossy(.stage, default: 1)
    rowVersion = container.lossy(.rowVersion, default: "")
  }

  package func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(day, forKey: .day)
    try container.encode(personId, forKey: .personId)
    try container.encode(activityId, forKey: .activityId)
    try container.encode(projectId, forKey: .projectId)
    try container.encode(hours, forKey: .hours)
    // The web app sends an explicit null here.
    if let remark {
      try container.encode(remark, forKey: .remark)
    } else {
      try container.encodeNil(forKey: .remark)
    }
    try container.encode(stage, forKey: .stage)
    try container.encode(rowVersion, forKey: .rowVersion)
  }
}
