import Foundation

public struct CharaDashaPeriod: Codable, Sendable, Equatable {
    public let rasi: Rasi
    public let years: Double
    public let startDate: Date
    public let endDate: Date
    /// Sub-periods within this one (Antardasha within a Mahadasha,
    /// Pratyantardasha within an Antardasha), if any -- empty at the
    /// deepest level.
    public let subPeriods: [CharaDashaPeriod]

    public init(rasi: Rasi, years: Double, startDate: Date, endDate: Date, subPeriods: [CharaDashaPeriod] = []) {
        self.rasi = rasi
        self.years = years
        self.startDate = startDate
        self.endDate = endDate
        self.subPeriods = subPeriods
    }
}

/// Chara Dasha (Jaimini), per Jaimini Sutras via modern restatements
/// (Sanjay Rath's transmission is the commonly-cited source; a primary
/// translation wasn't reachable during research). Confirmed with user
/// before implementation.
public enum CharaDasha {
    private static let exaltationSign: [CelestialBody: Rasi] = [
        .sun: .aries, .moon: .taurus, .mars: .capricorn, .mercury: .virgo,
        .jupiter: .cancer, .venus: .pisces, .saturn: .libra,
    ]
    private static let debilitationSign: [CelestialBody: Rasi] = [
        .sun: .libra, .moon: .scorpio, .mars: .cancer, .mercury: .pisces,
        .jupiter: .capricorn, .venus: .virgo, .saturn: .aries,
    ]

    /// Years of dasha for `rasi`, given where each classical planet is
    /// currently placed (its natal rasi). Counting is inclusive (same
    /// convention used everywhere else in this engine): the starting sign
    /// counts as 1, so a lord one sign away gives 2 years, etc. Direction
    /// of the count is this *sign's own* odd/even parity (forward if odd,
    /// backward if even) -- independent of the overall sequence direction,
    /// which is fixed once by the birth Lagna instead (see `sequence`).
    /// A lord posited in its own sign is the classical exception: always
    /// 12 years (the maximum), not whatever the count would give (1).
    /// Exalted lord: +1 year. Debilitated: -1 year, floored at 1.
    public static func years(for rasi: Rasi, lordPlacement: [CelestialBody: Rasi]) -> Double {
        let lord = rasi.lord
        guard let lordSign = lordPlacement[lord] else { return 1 }

        if lordSign == rasi {
            return 12
        }

        let distance = rasi.isOdd
            ? ((lordSign.rawValue - rasi.rawValue + 12) % 12) + 1
            : ((rasi.rawValue - lordSign.rawValue + 12) % 12) + 1
        var years = Double(distance)

        if exaltationSign[lord] == lordSign {
            years += 1
        } else if debilitationSign[lord] == lordSign {
            years -= 1
        }
        return max(years, 1)
    }

    /// One full cycle through all 12 signs from birth, starting at the
    /// Lagna sign. The sequence's direction (which sign follows which) is
    /// fixed once, by whether the Lagna sign itself is odd (forward
    /// through the zodiac) or even (backward) -- a separate question from
    /// each individual sign's own forward/backward length calculation.
    /// Each mahadasha recursively subdivides `subLevels` further times
    /// (default 2: antardasha, then pratyantardasha within it).
    public static func sequence(lagna: Rasi, lordPlacement: [CelestialBody: Rasi], birthDate: Date, subLevels: Int = 2) -> [CharaDashaPeriod] {
        let step = lagna.isOdd ? 1 : -1
        var periods: [CharaDashaPeriod] = []
        var cursor = birthDate
        for i in 0..<12 {
            let rasi = lagna.offset(i * step)
            let periodYears = years(for: rasi, lordPlacement: lordPlacement)
            let period = buildPeriod(rasi: rasi, direction: step, years: periodYears, start: cursor, subLevels: subLevels)
            periods.append(period)
            cursor = period.endDate
        }
        return periods
    }

    /// A period's own span divides into 12 equal sub-periods, one per sign,
    /// starting at the period's own rasi and running in the *same*
    /// direction as the top-level mahadasha sequence (the Lagna-parity-
    /// derived `direction`, fixed for the whole tree) -- not each sub-period
    /// rasi's own odd/even length rule, which only governs mahadasha
    /// lengths. Applied recursively: an antardasha's own pratyantardashas
    /// follow the identical equal-12-way-split rule, just one level deeper.
    private static func buildPeriod(rasi: Rasi, direction: Int, years: Double, start: Date, subLevels: Int) -> CharaDashaPeriod {
        let end = start.addingTimeInterval(years * VimshottariDasha.daysPerYear * 86400)
        guard subLevels > 0 else {
            return CharaDashaPeriod(rasi: rasi, years: years, startDate: start, endDate: end)
        }

        let subYears = years / 12
        var subPeriods: [CharaDashaPeriod] = []
        var cursor = start
        for i in 0..<12 {
            let subRasi = rasi.offset(i * direction)
            let sub = buildPeriod(rasi: subRasi, direction: direction, years: subYears, start: cursor, subLevels: subLevels - 1)
            subPeriods.append(sub)
            cursor = sub.endDate
        }
        return CharaDashaPeriod(rasi: rasi, years: years, startDate: start, endDate: end, subPeriods: subPeriods)
    }
}
