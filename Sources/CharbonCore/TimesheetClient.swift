import Foundation

private struct WeekEnvelope: Decodable {
  let timesheet: WeekTimesheet

  enum CodingKeys: String, CodingKey { case timesheet = "Timesheet" }
}

private struct EntryRow: Encodable {
  let isVisible = false
  let personId: Int
  let projectId: Int
  let activityId: Int
  let displayName = ""
  let rowVersion = ""

  enum CodingKeys: String, CodingKey {
    case isVisible = "IsVisible"
    case personId = "PersonId"
    case projectId = "ProjectId"
    case activityId = "ActivityId"
    case displayName = "DisplayName"
    case rowVersion = "RowVersion"
  }
}

/// Talks to the Timbrage web API with a session that already exists.
package struct TimesheetClient: Sendable {
  private let baseURL: URL
  private let transport: any HTTPTransport

  package init(transport: any HTTPTransport, baseURL: URL = CharbonEnvironment.baseURL) {
    self.transport = transport
    self.baseURL = baseURL
  }

  /// The week that contains `day`, written `yyyy-MM-dd`.
  ///
  /// The web app also sends the value of its `NoAGE` cookie as `no_age`, probably only to avoid
  /// caching.
  package func week(containing day: String, noAge: String? = nil) async throws -> WeekTimesheet {
    var query = [
      URLQueryItem(name: "getAllActivitiesForEachProject", value: "false"),
      URLQueryItem(name: "selected_date", value: day),
    ]
    if let noAge, !noAge.isEmpty {
      query.append(URLQueryItem(name: "no_age", value: noAge))
    }
    let request = try makeRequest("GET", "TimeSheet/Week", query: query)
    return try await decode(WeekEnvelope.self, from: request).timesheet
  }

  package func projects() async throws -> [ProjectSummary] {
    let request = try makeRequest("GET", "TimeSheet/GetProjects")
    return try await decode([ProjectSummary].self, from: request)
  }

  /// Saves a period and returns it with its new ids and row versions.
  package func updatePeriod(_ period: PeriodTime) async throws -> PeriodTime {
    let request = try makeRequest("PUT", "TimeSheet/UpdatePeriod", body: period)
    return try await decode(PeriodTime.self, from: request)
  }

  package func updateHours(_ entry: ProjectHours, modifierID: Int) async throws -> ProjectHours {
    let request = try makeRequest(
      "PUT",
      "TimeSheet/UpdateHoursAttribution",
      query: [URLQueryItem(name: "the_modifier_id", value: String(modifierID))],
      body: entry
    )
    return try await decode(ProjectHours.self, from: request)
  }

  /// Adds a project activity as a row of the week, so hours can be booked on it.
  package func addRow(personID: Int, projectID: Int, activityID: Int) async throws {
    let row = EntryRow(personId: personID, projectId: projectID, activityId: activityID)
    let request = try makeRequest("PUT", "TimeSheet/AddEntry", body: row)
    _ = try await perform(request)
  }

  private func makeRequest(
    _ method: String,
    _ path: String,
    query: [URLQueryItem] = [],
    body: (any Encodable)? = nil
  ) throws -> URLRequest {
    let endpoint = baseURL.absoluteString + CharbonEnvironment.apiPath + path
    guard var components = URLComponents(string: endpoint) else {
      throw CharbonError.invalidResponse("bad URL \(endpoint)")
    }
    if !query.isEmpty {
      components.queryItems = query
    }
    guard let url = components.url else {
      throw CharbonError.invalidResponse("bad URL \(endpoint)")
    }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
    request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Origin")
    request.setValue(baseURL.absoluteString + "/", forHTTPHeaderField: "Referer")
    if let body {
      request.setValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONEncoder().encode(body)
    }
    return request
  }

  private func decode<T: Decodable>(_ type: T.Type, from request: URLRequest) async throws -> T {
    let data = try await perform(request)
    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      throw CharbonError.invalidResponse("could not decode \(T.self)")
    }
  }

  private func perform(_ request: URLRequest) async throws -> Data {
    let data: Data
    let response: HTTPURLResponse
    do {
      (data, response) = try await transport.send(request)
    } catch let error as CharbonError {
      throw error
    } catch {
      throw CharbonError.network(error.localizedDescription)
    }
    try Self.validate(data: data, response: response)
    return data
  }

  static func validate(data: Data, response: HTTPURLResponse) throws {
    switch response.statusCode {
    case 200..<300:
      // A login page where JSON was expected means the session is gone.
      let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
      if contentType.contains("text/html") {
        throw CharbonError.sessionExpired
      }
    case 300..<400, 401, 403, 404:
      throw CharbonError.sessionExpired
    case 426:
      throw CharbonError.staleData
    default:
      throw CharbonError.server(status: response.statusCode, message: serverMessage(from: data))
    }
  }

  private static func serverMessage(from data: Data) -> String {
    guard
      let object = try? JSONSerialization.jsonObject(with: data),
      let dictionary = object as? [String: Any]
    else {
      return ""
    }
    for key in ["ErrorMessage", "Message", "ExceptionMessage"] {
      if let message = dictionary[key] as? String, !message.isEmpty {
        return message
      }
    }
    return ""
  }
}
