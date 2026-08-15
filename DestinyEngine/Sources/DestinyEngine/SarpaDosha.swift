/// Sarpa Dosha, per user-supplied rule (replaces an earlier Kaal-Sarp-style
/// "all 7 planets hemmed by the Rahu-Ketu axis" implementation): present
/// when any of the 9 graha (7 classical planets + Rahu/Ketu) falls within
/// one of three specific degree ranges -- Cancer 10-30deg, Scorpio 0-20deg,
/// Pisces 20-30deg.
public struct SarpaDoshaResult: Codable, Sendable, Equatable {
    public let isPresent: Bool
    /// Which bodies triggered it, in CelestialBody.allCases order (empty if not present).
    public let triggeringBodies: [CelestialBody]

    public init(isPresent: Bool, triggeringBodies: [CelestialBody]) {
        self.isPresent = isPresent
        self.triggeringBodies = triggeringBodies
    }
}

public enum SarpaDosha {
    /// (rasi, degree-within-sign range) pairs that count as a Sarpa segment.
    private static let sarpaRanges: [(rasi: Rasi, range: Range<Double>)] = [
        (.cancer, 10..<30),
        (.scorpio, 0..<20),
        (.pisces, 20..<30),
    ]

    public static func evaluate(longitudes: [CelestialBody: Double]) -> SarpaDoshaResult {
        var triggering: [CelestialBody] = []
        for body in CelestialBody.allCases {
            guard let longitude = longitudes[body] else { continue }
            let rasi = Rasi.containing(longitude: longitude)
            let degreeInSign = AngleMath.degreeWithinSign(longitude)
            if sarpaRanges.contains(where: { $0.rasi == rasi && $0.range.contains(degreeInSign) }) {
                triggering.append(body)
            }
        }
        return SarpaDoshaResult(isPresent: !triggering.isEmpty, triggeringBodies: triggering)
    }
}
