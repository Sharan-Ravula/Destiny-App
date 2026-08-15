import Foundation

public struct DashaPeriod: Codable, Sendable, Equatable {
    public let lord: CelestialBody
    public let startDate: Date
    public let endDate: Date
    public let subPeriods: [DashaPeriod]

    public init(lord: CelestialBody, startDate: Date, endDate: Date, subPeriods: [DashaPeriod] = []) {
        self.lord = lord
        self.startDate = startDate
        self.endDate = endDate
        self.subPeriods = subPeriods
    }
}

public enum VimshottariDasha {
    public static let totalCycleYears: Double = 120

    /// Days per year used to convert dasha durations (years) into calendar
    /// dates. 365.2425 = the mean Gregorian year. Flagging honestly: Vedic
    /// software isn't consistent here -- some use 365.25, some the
    /// sidereal year (~365.2564). This affects sub-day precision on
    /// periods decades out, not the underlying year/proportion math.
    public static let daysPerYear: Double = 365.2425

    public static let yearsByLord: [CelestialBody: Double] = [
        .ketu: 7, .venus: 20, .sun: 6, .moon: 10, .mars: 7,
        .rahu: 18, .jupiter: 16, .saturn: 19, .mercury: 17,
    ]

    private static var order: [CelestialBody] { Nakshatra.vimshottariLordCycle }

    /// The nakshatra lord whose mahadasha is running at birth, and how
    /// many years of it remain -- proportional to how much of the birth
    /// nakshatra's span the Moon has yet to travel through.
    public static func balanceAtBirth(moonLongitude: Double) -> (lord: CelestialBody, remainingYears: Double) {
        let normalized = AngleMath.normalizedDegrees(moonLongitude)
        let nakshatraIndex = min(Int(normalized / Nakshatra.span), 26)
        let elapsed = normalized - Double(nakshatraIndex) * Nakshatra.span
        let remainingFraction = (Nakshatra.span - elapsed) / Nakshatra.span
        let lord = Nakshatra(rawValue: nakshatraIndex)!.lord
        return (lord, yearsByLord[lord]! * remainingFraction)
    }

    /// One full cycle of 9 mahadashas from birth -- the birth nakshatra
    /// lord's partial remaining period first, then the other 8 lords in
    /// full, each recursively subdivided `subLevels` further times
    /// (default 2: antardasha, then pratyantardasha within it).
    public static func mahadashaSequence(moonLongitude: Double, birthDate: Date, subLevels: Int = 2) -> [DashaPeriod] {
        let (startLord, remainingYears) = balanceAtBirth(moonLongitude: moonLongitude)
        guard let startIndex = order.firstIndex(of: startLord) else { return [] }

        var periods: [DashaPeriod] = []
        var cursor = birthDate
        for step in 0..<9 {
            let lord = order[(startIndex + step) % 9]
            let years = step == 0 ? remainingYears : yearsByLord[lord]!
            let period = buildPeriod(lord: lord, years: years, start: cursor, subLevels: subLevels)
            periods.append(period)
            cursor = period.endDate
        }
        return periods
    }

    /// A period always starts its own sub-cycle at its own lord (e.g. a
    /// Venus mahadasha's antardashas begin with Venus-Venus), then
    /// proceeds through the standard 9-lord order, each sub-period's
    /// length a proportional share of the *parent's actual* duration
    /// (which may itself already be a birth-shortened partial period).
    private static func buildPeriod(lord: CelestialBody, years: Double, start: Date, subLevels: Int) -> DashaPeriod {
        let end = addYears(years, to: start)
        guard subLevels > 0, let startIndex = order.firstIndex(of: lord) else {
            return DashaPeriod(lord: lord, startDate: start, endDate: end)
        }

        var subPeriods: [DashaPeriod] = []
        var cursor = start
        for step in 0..<9 {
            let subLord = order[(startIndex + step) % 9]
            let subYears = years * (yearsByLord[subLord]! / totalCycleYears)
            let sub = buildPeriod(lord: subLord, years: subYears, start: cursor, subLevels: subLevels - 1)
            subPeriods.append(sub)
            cursor = sub.endDate
        }
        return DashaPeriod(lord: lord, startDate: start, endDate: end, subPeriods: subPeriods)
    }

    private static func addYears(_ years: Double, to date: Date) -> Date {
        date.addingTimeInterval(years * daysPerYear * 86400)
    }
}
