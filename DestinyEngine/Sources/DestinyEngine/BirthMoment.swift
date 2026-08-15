import Foundation

/// Local wall-clock birth time plus enough information to resolve it to an
/// absolute UTC instant. Resolution normally goes through the IANA time
/// zone database (which encodes historical DST/offset rules), but
/// `manualUTCOffsetSeconds` is an escape hatch for dates/places where that
/// database is known to be wrong or too coarse.
public struct BirthMoment: Sendable, Codable, Equatable {
    public var year: Int
    public var month: Int
    public var day: Int
    public var hour: Int
    public var minute: Int
    public var second: Double
    /// IANA identifier, e.g. "Asia/Kolkata".
    public var timeZoneIdentifier: String
    public var manualUTCOffsetSeconds: Int?

    public init(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Double = 0,
                timeZoneIdentifier: String, manualUTCOffsetSeconds: Int? = nil) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.timeZoneIdentifier = timeZoneIdentifier
        self.manualUTCOffsetSeconds = manualUTCOffsetSeconds
    }

    public enum ResolutionError: Error, Sendable, Equatable {
        case unknownTimeZone(String)
        case invalidComponents
    }

    public func resolvedUTCDate() throws -> Date {
        let timeZone: TimeZone
        if let manualOffset = manualUTCOffsetSeconds {
            guard let fixed = TimeZone(secondsFromGMT: manualOffset) else {
                throw ResolutionError.invalidComponents
            }
            timeZone = fixed
        } else {
            guard let resolved = TimeZone(identifier: timeZoneIdentifier) else {
                throw ResolutionError.unknownTimeZone(timeZoneIdentifier)
            }
            timeZone = resolved
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = Int(second)

        guard let date = calendar.date(from: components) else {
            throw ResolutionError.invalidComponents
        }
        return date
    }
}
