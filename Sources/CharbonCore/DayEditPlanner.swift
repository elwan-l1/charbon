import Foundation

/// The wanted times of one period of a day. `nil` leaves a time empty.
package struct PeriodEdit: Equatable, Sendable {
  package var displayOrder: Int
  package var arrival: ClockTime?
  package var departure: ClockTime?

  package init(displayOrder: Int, arrival: ClockTime? = nil, departure: ClockTime? = nil) {
    self.displayOrder = displayOrder
    self.arrival = arrival
    self.departure = departure
  }

  package init(_ period: PeriodTime) {
    displayOrder = period.displayOrder
    arrival = period.arrival.clockTime
    departure = period.departure.clockTime
  }

  fileprivate var isEmpty: Bool {
    arrival == nil && departure == nil
  }
}

/// Works out which periods to save for a day the user edited.
package enum DayEditPlanner {
  /// The periods to send, in order.
  ///
  /// Periods that do not change are left out, and a period left empty that does not exist yet is
  /// never created.
  package static func plan(day: WeekDay, personID: Int, edits: [PeriodEdit]) throws
    -> [PeriodTime]
  {
    let ordered = edits.sorted { $0.displayOrder < $1.displayOrder }
    try validate(ordered)
    return ordered.compactMap { edit in
      let existing = day.periods.first { $0.displayOrder == edit.displayOrder }
      if let existing, PeriodEdit(existing) == edit {
        return nil
      }
      if existing == nil, edit.isEmpty {
        return nil
      }
      var period =
        existing
        ?? PeriodTime(
          displayOrder: edit.displayOrder,
          personId: personID,
          day: day.date,
          stage: day.stage
        )
      period.arrival.time = edit.arrival?.description ?? ""
      period.departure.time = edit.departure?.description ?? ""
      return period
    }
  }

  private static func validate(_ edits: [PeriodEdit]) throws {
    var previousEnd: ClockTime?
    var openOrder: Int?
    for edit in edits where !edit.isEmpty {
      guard let arrival = edit.arrival else {
        throw CharbonError.invalidEdit("A departure needs an arrival.")
      }
      if openOrder != nil {
        throw CharbonError.invalidEdit("Only the last period can be left without a departure.")
      }
      if let previousEnd, arrival < previousEnd {
        throw CharbonError.startsBeforePreviousPeriod(previousDeparture: previousEnd.description)
      }
      guard let departure = edit.departure else {
        openOrder = edit.displayOrder
        continue
      }
      guard departure > arrival else {
        throw CharbonError.invalidEdit(
          "The departure at \(departure) must be later than the arrival at \(arrival).")
      }
      previousEnd = departure
    }
  }
}
