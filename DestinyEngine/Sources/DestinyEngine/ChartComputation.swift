public struct ChartPoint: Codable, Sendable, Equatable {
    public let absoluteLongitude: Double
    public let rasi: Rasi
    public let nakshatra: Nakshatra

    public init(absoluteLongitude: Double, rasi: Rasi, nakshatra: Nakshatra) {
        self.absoluteLongitude = absoluteLongitude
        self.rasi = rasi
        self.nakshatra = nakshatra
    }
}

public struct ChartRow: Codable, Sendable, Equatable {
    public let body: CelestialBody
    public let absoluteLongitude: Double
    public let degreeWithinSign: Double
    public let rasi: Rasi
    public let nakshatra: Nakshatra
    public let isRetrograde: Bool
    public let isCombust: Bool
    /// nil for Rahu/Ketu, which are excluded from the 7-karaka scheme.
    public let karaka: KarakaRole?

    public init(body: CelestialBody, absoluteLongitude: Double, degreeWithinSign: Double, rasi: Rasi,
                nakshatra: Nakshatra, isRetrograde: Bool, isCombust: Bool, karaka: KarakaRole?) {
        self.body = body
        self.absoluteLongitude = absoluteLongitude
        self.degreeWithinSign = degreeWithinSign
        self.rasi = rasi
        self.nakshatra = nakshatra
        self.isRetrograde = isRetrograde
        self.isCombust = isCombust
        self.karaka = karaka
    }
}

/// Purely the calculated output of a birth chart -- the app never persists
/// this to disk (a saved chart's JSON holds only its raw inputs and
/// recomputes this fresh on load), so no backward-compatible/lenient
/// decoding concerns apply here; a plain synthesized Codable is enough for
/// whatever in-memory or debugging use wants to serialize it.
public struct ChartComputation: Codable, Sendable, Equatable {
    public let ascendant: ChartPoint
    /// Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Rahu, Ketu -- in
    /// that order (matches CelestialBody.allCases).
    public let rows: [ChartRow]
    /// D1 (Rasi) is `rows`/`ascendant` above; this covers D2-D60.
    public let vargas: [VargaChart]
    /// One full cycle of mahadashas from birth, each holding antardasha
    /// and pratyantardasha sub-periods -- see VimshottariDasha.
    public let vimshottariDasha: [DashaPeriod]
    /// One full cycle through all 12 signs from birth -- see CharaDasha.
    public let charaDasha: [CharaDashaPeriod]
    /// Conjunctions, graha drishti aspects, house lordship placements,
    /// Mangal/Sarpa dosha flags -- all derived from `rows`/`ascendant` above.
    public let summary: ChartSummary

    public init(ascendant: ChartPoint, rows: [ChartRow], vargas: [VargaChart],
                vimshottariDasha: [DashaPeriod], charaDasha: [CharaDashaPeriod], summary: ChartSummary) {
        self.ascendant = ascendant
        self.rows = rows
        self.vargas = vargas
        self.vimshottariDasha = vimshottariDasha
        self.charaDasha = charaDasha
        self.summary = summary
    }
}
