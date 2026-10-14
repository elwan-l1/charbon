import Foundation

/// Decides which period to write for a clock in or a clock out.
package enum StampPlanner {
  /// The first empty period gets the arrival, or a new period after the last one if none is empty.
  package static func clockIn(day: WeekDay, personID: Int, now: ClockTime) throws -> PeriodTime {
    let ordered = day.periods.sorted { $0.displayOrder < $1.displayOrder }
    if let since = ordered.last(where: \.isOpen)?.arrival.clockTime {
      throw CharbonError.alreadyClockedIn(since: since.description)
    }
    if let lastDeparture = ordered.compactMap(\.departure.clockTime).max(), now < lastDeparture {
      throw CharbonError.startsBeforePreviousPeriod(previousDeparture: lastDeparture.description)
    }
    var period =
      ordered.first(where: \.isEmpty)
      ?? PeriodTime(
        displayOrder: (ordered.last?.displayOrder ?? -1) + 1,
        personId: personID,
        day: day.date,
        stage: day.stage
      )
    period.arrival.time = now.description
    period.departure.time = ""
    return period
  }

  package static func clockOut(day: WeekDay, now: ClockTime) throws -> PeriodTime {
    guard var period = day.openPeriod, let arrival = period.arrival.clockTime else {
      throw CharbonError.notClockedIn
    }
    guard now > arrival else {
      throw CharbonError.endsBeforeStart(arrival: arrival.description, departure: now.description)
    }
    period.departure.time = now.description
    return period
  }
}
